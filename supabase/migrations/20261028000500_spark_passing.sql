begin;
create table public.contributions (
 id uuid primary key default gen_random_uuid(),
 group_id uuid not null references public.groups(id) on delete cascade,
 turn_version bigint not null check(turn_version>0),
 sender_id uuid not null references public.profiles(id),
 recipient_id uuid not null references public.profiles(id),
 sender_name text not null,
 recipient_name text not null,
 prompt_id uuid not null,
 prompt_text text not null,
 answer text not null check(answer !~ '^[[:space:]]*$' and octet_length(answer)<=12000),
 created_at timestamptz not null default now(),
 check(sender_id<>recipient_id),
 unique(group_id,turn_version)
);
create index contributions_group_created_idx on public.contributions(group_id,created_at desc);
alter table public.contributions enable row level security;
revoke all on public.contributions from public,anon,authenticated;
grant select on public.contributions to authenticated;
create policy contributions_members_read on public.contributions for select to authenticated using(private.is_member(group_id));

create function public.pass_spark(p_group_id uuid,p_expected_version bigint,p_prompt_id uuid,p_recipient_id uuid,p_answer text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_state public.spark_states; v_saved public.contributions; v_answer text:=btrim(p_answer); v_sender text; v_recipient text;
begin
 if auth.uid() is null or not private.is_member(p_group_id) then raise exception 'This group is not available to you.' using errcode='42501'; end if;
 if v_answer is null or v_answer ~ '^[[:space:]]*$' or octet_length(v_answer)>12000 then raise exception 'Write an answer before passing. Keep it within the answer limit.' using errcode='22023'; end if;
 select * into v_state from public.spark_states where group_id=p_group_id for update;
 if not found then raise exception 'The spark is unavailable. Refresh the group.' using errcode='22023'; end if;
 select * into v_saved from public.contributions where group_id=p_group_id and turn_version=p_expected_version;
 if found then
  if v_saved.sender_id=auth.uid() and v_saved.recipient_id=p_recipient_id and v_saved.prompt_id=p_prompt_id and v_saved.answer=v_answer then return to_jsonb(v_saved); end if;
  raise exception 'This turn has already been passed. Refresh the group and check its timeline.' using errcode='22023';
 end if;
 if v_state.holder_id<>auth.uid() then raise exception 'Only the current holder can pass the spark.' using errcode='42501'; end if;
 if p_expected_version is null or v_state.version<>p_expected_version or p_prompt_id is null or v_state.prompt_id<>p_prompt_id then raise exception 'Your turn has changed. Your draft is still on this device. Refresh the group.' using errcode='22023'; end if;
 if p_recipient_id is null or p_recipient_id=auth.uid() then raise exception 'Choose another group member.' using errcode='22023'; end if;
 -- Matches leave's spark-before-membership order and prevents recipient departure during this write.
 perform 1 from public.memberships where group_id=p_group_id and user_id=p_recipient_id for key share;
 if not found then raise exception 'This person is no longer a group member. Choose another member.' using errcode='22023'; end if;
 select display_name into v_sender from public.profiles where id=auth.uid();
 select display_name into v_recipient from public.profiles where id=p_recipient_id;
 insert into public.contributions(group_id,turn_version,sender_id,recipient_id,sender_name,recipient_name,prompt_id,prompt_text,answer)
 values(p_group_id,v_state.version,auth.uid(),p_recipient_id,v_sender,v_recipient,v_state.prompt_id,v_state.prompt_text,v_answer) returning * into v_saved;
 update public.spark_states set holder_id=p_recipient_id,version=version+1,prompt_id=gen_random_uuid() where group_id=p_group_id;
 return to_jsonb(v_saved);
end $$;

create function public.group_contributions(p_group_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not private.is_member(p_group_id) then raise exception 'This group is not available to you.' using errcode='42501'; end if;
 return coalesce((select jsonb_agg(to_jsonb(c) order by c.turn_version desc) from (select * from public.contributions where group_id=p_group_id order by turn_version desc limit 100)c),'[]'::jsonb);
end $$;

create or replace function private.group_card(p_group_id uuid) returns jsonb
language sql stable security definer set search_path='' as $$
select jsonb_build_object('id',g.id,'name',g.name,'member_count',(select count(*) from public.memberships m where m.group_id=g.id),'holder_id',s.holder_id,'holder_name',p.display_name,'prompt_id',s.prompt_id,'prompt',s.prompt_text,'version',s.version)
from public.groups g join public.spark_states s on s.group_id=g.id join public.profiles p on p.id=s.holder_id where g.id=p_group_id
$$;
revoke all on function public.pass_spark(uuid,bigint,uuid,uuid,text),public.group_contributions(uuid) from public,anon;
grant execute on function public.pass_spark(uuid,bigint,uuid,uuid,text),public.group_contributions(uuid) to authenticated;
create or replace function public.my_group_overview() returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Sign in to continue.' using errcode='42501'; end if;
 return jsonb_build_object('viewer_id',auth.uid(),
 'groups',coalesce((select jsonb_agg(private.group_card(g.id) order by g.created_at,g.id) from public.groups g where private.is_member(g.id)),'[]'::jsonb),
 'requests',coalesce((select jsonb_agg(jsonb_build_object('group_id',g.id,'group_name',g.name) order by r.created_at,r.id) from public.join_requests r join public.groups g on g.id=r.group_id where r.user_id=auth.uid() and r.status='pending'),'[]'::jsonb),
 'invitations',coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'group_id',g.id,'group_name',g.name) order by i.created_at,i.id) from public.group_invitations i join public.groups g on g.id=i.group_id join auth.users u on u.id=auth.uid() and u.email_confirmed_at is not null and lower(u.email)=i.recipient_email where i.status='pending' and i.expires_at>now() and not private.is_member(g.id)),'[]'::jsonb),
 'activities',coalesce((select jsonb_agg(to_jsonb(activity) order by activity.created_at desc,activity.id desc) from (
   select c.id,c.sender_name,c.recipient_name,c.created_at,g.name as group_name
   from public.contributions c join public.groups g on g.id=c.group_id
   where private.is_member(g.id) order by c.created_at desc,c.id desc limit 10
 )activity),'[]'::jsonb));
end $$;

commit;
