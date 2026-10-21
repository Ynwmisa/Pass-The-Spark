begin;

create table public.group_invitations (
 id uuid primary key default gen_random_uuid(),
 group_id uuid not null references public.groups(id) on delete cascade,
 recipient_email text not null check (recipient_email = lower(btrim(recipient_email)) and char_length(recipient_email) between 3 and 254),
 invited_by uuid not null references public.profiles(id),
 request_id uuid not null,
 status text not null default 'pending' check (status in ('pending','accepted','declined')),
 responded_by uuid references public.profiles(id),
 created_at timestamptz not null default now(),
 expires_at timestamptz not null default now() + interval '7 days',
 unique(invited_by,request_id)
);
create index group_invitations_recipient_idx on public.group_invitations(recipient_email);
alter table public.group_invitations enable row level security;
revoke all on public.group_invitations from public, anon, authenticated;

create function public.invite_group_member(p_group_id uuid,p_email text,p_request_id uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare v_email text := lower(btrim(p_email)); v_inv public.group_invitations;
begin
 if auth.uid() is null or not private.is_organiser(p_group_id) then
  raise exception 'Only the group organiser can invite members.' using errcode='42501';
 end if;
 if v_email is null or char_length(v_email)>254 or v_email !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$' or p_request_id is null then
  raise exception 'Enter a valid email address.' using errcode='22023';
 end if;
 -- Serialize sends within this group, including retries from different devices.
 perform 1 from public.groups where id=p_group_id for update;
 select * into v_inv from public.group_invitations where invited_by=auth.uid() and request_id=p_request_id;
 if found then
  if v_inv.group_id<>p_group_id or v_inv.recipient_email<>v_email then
   raise exception 'This request was already used for another invitation.' using errcode='22023';
  end if;
  return v_inv.id;
 end if;
 if exists(select 1 from public.memberships m join auth.users u on u.id=m.user_id where m.group_id=p_group_id and lower(u.email)=v_email and u.email_confirmed_at is not null) then
  raise exception 'This person already belongs to the group.' using errcode='22023';
 end if;
 select * into v_inv from public.group_invitations where group_id=p_group_id and recipient_email=v_email and status='pending' and expires_at>now() order by created_at desc limit 1;
 if found then return v_inv.id; end if;
 insert into public.group_invitations(group_id,recipient_email,invited_by,request_id)
 values(p_group_id,v_email,auth.uid(),p_request_id) returning * into v_inv;
 return v_inv.id;
end $$;

create function public.respond_to_group_invitation(p_invitation_id uuid,p_accept boolean) returns void
language plpgsql security definer set search_path='' as $$
declare v_inv public.group_invitations; v_email text;
begin
 select lower(email) into v_email from auth.users where id=auth.uid() and email_confirmed_at is not null;
 if v_email is null then raise exception 'Confirm your email before responding to invitations.' using errcode='42501'; end if;
 if p_accept is null then raise exception 'Choose accept or decline.' using errcode='22023'; end if;
 -- Coordinate with leaving and future holder changes before request/member locks.
 perform 1 from public.spark_states where group_id=(select group_id from public.group_invitations where id=p_invitation_id) for update;
 select * into v_inv from public.group_invitations where id=p_invitation_id for update;
 if not found or v_inv.recipient_email<>v_email then
  raise exception 'This invitation is not available to you.' using errcode='42501';
 end if;
 if v_inv.status<>'pending' then
  if v_inv.responded_by=auth.uid() and ((v_inv.status='accepted' and p_accept and private.is_member(v_inv.group_id)) or (v_inv.status='declined' and not p_accept)) then return; end if;
  raise exception 'This invitation has already been answered.' using errcode='22023';
 end if;
 if v_inv.expires_at<=now() then raise exception 'This invitation has expired.' using errcode='22023'; end if;
 if p_accept then
  perform 1 from public.join_requests where group_id=v_inv.group_id and user_id=auth.uid() for update;
  insert into public.memberships(group_id,user_id) values(v_inv.group_id,auth.uid()) on conflict do nothing;
  update public.join_requests set status='approved' where group_id=v_inv.group_id and user_id=auth.uid() and status='pending';
 end if;
 update public.group_invitations set status=case when p_accept then 'accepted' else 'declined' end,responded_by=auth.uid() where id=v_inv.id;
end $$;

create or replace function public.my_group_overview() returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Sign in to continue.' using errcode='42501'; end if;
 return jsonb_build_object('viewer_id',auth.uid(),
 'groups',coalesce((select jsonb_agg(private.group_card(g.id) order by g.created_at,g.id) from public.groups g where private.is_member(g.id)),'[]'::jsonb),
 'requests',coalesce((select jsonb_agg(jsonb_build_object('group_id',g.id,'group_name',g.name) order by r.created_at,r.id) from public.join_requests r join public.groups g on g.id=r.group_id where r.user_id=auth.uid() and r.status='pending'),'[]'::jsonb),
 'invitations',coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'group_id',g.id,'group_name',g.name) order by i.created_at,i.id) from public.group_invitations i join public.groups g on g.id=i.group_id join auth.users u on u.id=auth.uid() and u.email_confirmed_at is not null and lower(u.email)=i.recipient_email where i.status='pending' and i.expires_at>now() and not private.is_member(g.id)),'[]'::jsonb));
end $$;
revoke all on function public.invite_group_member(uuid,text,uuid), public.respond_to_group_invitation(uuid,boolean), public.my_group_overview() from public,anon;
grant execute on function public.invite_group_member(uuid,text,uuid), public.respond_to_group_invitation(uuid,boolean), public.my_group_overview() to authenticated;
commit;
