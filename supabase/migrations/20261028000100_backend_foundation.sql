-- Pass the Spark database foundation.
-- Run once in a new Supabase project's SQL Editor.
-- Passwords and email verification belong to Supabase Auth, not these tables.
begin;

create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(btrim(display_name)) between 1 and 60),
  created_at timestamptz not null default now()
);
create table public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 1 and 60),
  created_by uuid not null references public.profiles(id),
  creation_request_id uuid not null,
  created_at timestamptz not null default now(),
  unique (created_by, creation_request_id)
);
create table public.memberships (
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references public.profiles(id),
  role text not null default 'member' check (role in ('organiser','member')),
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);
create index memberships_user_id_idx on public.memberships(user_id);
create unique index one_organiser_per_group on public.memberships(group_id) where role = 'organiser';

create table public.spark_states (
  group_id uuid primary key references public.groups(id) on delete cascade,
  holder_id uuid not null,
  prompt_id uuid not null default gen_random_uuid(),
  prompt_text text not null default 'What helped your group connect this week?',
  version bigint not null default 1 check (version > 0),
  foreign key (group_id, holder_id) references public.memberships(group_id,user_id)
);
create table public.invite_codes (
  group_id uuid primary key references public.groups(id) on delete cascade,
  code text not null unique check (code ~ '^[A-Z0-9]{12}$'),
  expires_at timestamptz not null default now() + interval '7 days'
);
create table public.join_requests (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references public.profiles(id),
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at timestamptz not null default now(),
  unique (group_id,user_id)
);
create index join_requests_user_id_idx on public.join_requests(user_id);

create function private.is_member(p_group_id uuid) returns boolean
language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.memberships
  where group_id = p_group_id and user_id = (select auth.uid())) $$;
create function private.is_organiser(p_group_id uuid) returns boolean
language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.memberships
  where group_id = p_group_id and user_id = (select auth.uid()) and role = 'organiser') $$;
create function private.shares_group(p_user_id uuid) returns boolean
language sql stable security definer set search_path = ''
as $$ select exists (
  select 1 from public.memberships mine join public.memberships other using (group_id)
  where mine.user_id = (select auth.uid()) and other.user_id = p_user_id) $$;
revoke all on function private.is_member(uuid), private.is_organiser(uuid), private.shares_group(uuid) from public, anon;
grant execute on function private.is_member(uuid), private.is_organiser(uuid), private.shares_group(uuid) to authenticated;

-- Profile creation is part of Auth sign-up. User metadata supplies a name only,
-- never a role, membership or holder identity.
create function private.handle_new_user() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.profiles(id,display_name)
  values (new.id, coalesce(nullif(left(btrim(new.raw_user_meta_data->>'display_name'),60),''),'Student'));
  return new;
end $$;
revoke all on function private.handle_new_user() from public, anon, authenticated;
create trigger on_auth_user_created after insert on auth.users
for each row execute function private.handle_new_user();
-- Supports test accounts created just before this migration, without replacing names.
insert into public.profiles(id,display_name)
select id, coalesce(nullif(left(btrim(raw_user_meta_data->>'display_name'),60),''),'Student')
from auth.users on conflict (id) do nothing;

alter table public.profiles enable row level security;
alter table public.groups enable row level security;
alter table public.memberships enable row level security;
alter table public.spark_states enable row level security;
alter table public.invite_codes enable row level security;
alter table public.join_requests enable row level security;

revoke all on public.profiles, public.groups, public.memberships,
  public.spark_states, public.invite_codes, public.join_requests from anon, authenticated;
grant select on public.profiles, public.groups, public.memberships,
  public.spark_states, public.invite_codes, public.join_requests to authenticated;
grant update(display_name) on public.profiles to authenticated;

create policy profiles_read on public.profiles for select to authenticated
using (id = (select auth.uid()) or private.shares_group(id));
create policy profiles_own_update on public.profiles for update to authenticated
using (id = (select auth.uid())) with check (id = (select auth.uid()));
create policy groups_members_read on public.groups for select to authenticated
using (private.is_member(id));
create policy memberships_members_read on public.memberships for select to authenticated
using (private.is_member(group_id));
create policy spark_members_read on public.spark_states for select to authenticated
using (private.is_member(group_id));
create policy codes_organiser_read on public.invite_codes for select to authenticated
using (private.is_organiser(group_id));
create policy requests_own_or_organiser_read on public.join_requests for select to authenticated
using (user_id = (select auth.uid()) or private.is_organiser(group_id));

create function private.group_card(p_group_id uuid) returns jsonb
language sql stable security definer set search_path = ''
as $$
select jsonb_build_object(
 'id',g.id,'name',g.name,'member_count',(select count(*) from public.memberships m where m.group_id=g.id),
 'holder_id',s.holder_id,'holder_name',p.display_name,
 'prompt_id',s.prompt_id,'prompt',s.prompt_text)
from public.groups g join public.spark_states s on s.group_id=g.id
join public.profiles p on p.id=s.holder_id where g.id=p_group_id
$$;
revoke all on function private.group_card(uuid) from public, anon, authenticated;

create function public.my_group_overview() returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
begin
 if auth.uid() is null then raise exception 'Sign in to continue.' using errcode='42501'; end if;
 return jsonb_build_object('viewer_id',auth.uid(),
 'groups',coalesce((select jsonb_agg(private.group_card(g.id) order by g.created_at,g.id)
   from public.groups g where private.is_member(g.id)),'[]'::jsonb),
 'requests',coalesce((select jsonb_agg(jsonb_build_object('group_id',g.id,'group_name',g.name)
     order by r.created_at,r.id)
   from public.join_requests r join public.groups g on g.id=r.group_id
   where r.user_id=auth.uid() and r.status='pending'),'[]'::jsonb));
end $$;

create function public.group_context(p_group_id uuid) returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
begin
 if auth.uid() is null or not private.is_member(p_group_id) then
   raise exception 'This group is not available to you.' using errcode='42501';
 end if;
 return jsonb_build_object('viewer_id',auth.uid(),'group',private.group_card(p_group_id),
 'members',(select jsonb_agg(jsonb_build_object('id',p.id,'name',p.display_name,
   'is_organiser',m.role='organiser') order by m.joined_at,p.id)
   from public.memberships m join public.profiles p on p.id=m.user_id where m.group_id=p_group_id),
 'invite_code',(select code from public.invite_codes where group_id=p_group_id
    and expires_at>now() and private.is_organiser(p_group_id)));
end $$;

create function public.create_group(p_name text, p_request_id uuid) returns uuid
language plpgsql security definer set search_path = ''
as $$
declare v_id uuid; v_name text := btrim(p_name);
begin
 if auth.uid() is null then raise exception 'Sign in to continue.' using errcode='42501'; end if;
 if v_name is null or char_length(v_name) not between 1 and 60 or v_name ~ '[[:cntrl:]]' then
   raise exception 'Use a group name of 1 to 60 characters, without control characters.' using errcode='22023';
 end if;
 if p_request_id is null then raise exception 'A request ID is required.' using errcode='22023'; end if;
 insert into public.groups(name,created_by,creation_request_id)
 values(v_name,auth.uid(),p_request_id) on conflict(created_by,creation_request_id) do nothing
 returning id into v_id;
 if v_id is null then
   select id into v_id from public.groups where created_by=auth.uid() and creation_request_id=p_request_id and name=v_name;
   if v_id is null then raise exception 'This request ID was already used for another name.' using errcode='22023'; end if;
   return v_id;
 end if;
 insert into public.memberships(group_id,user_id,role) values(v_id,auth.uid(),'organiser');
 insert into public.spark_states(group_id,holder_id) values(v_id,auth.uid());
 insert into public.invite_codes(group_id,code)
 values(v_id,upper(substr(replace(gen_random_uuid()::text,'-',''),1,12)));
 return v_id;
end $$;

create function public.request_to_join(p_code text) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare v_group public.groups; v_status text;
begin
 if auth.uid() is null then raise exception 'Sign in to continue.' using errcode='42501'; end if;
 select g.* into v_group from public.invite_codes c join public.groups g on g.id=c.group_id
 where c.code=upper(btrim(p_code)) and c.expires_at>now();
 if not found then raise exception 'This code is invalid or expired.' using errcode='22023'; end if;
 if private.is_member(v_group.id) then raise exception 'You already belong to this group.' using errcode='22023'; end if;
 insert into public.join_requests(group_id,user_id) values(v_group.id,auth.uid()) on conflict(group_id,user_id) do nothing;
 select status into v_status from public.join_requests where group_id=v_group.id and user_id=auth.uid();
 if v_status<>'pending' then raise exception 'This request has already been reviewed.' using errcode='22023'; end if;
 return jsonb_build_object('group_id',v_group.id,'group_name',v_group.name);
end $$;

create function public.approve_join_request(p_request_id uuid) returns void
language plpgsql security definer set search_path = ''
as $$
declare v_request public.join_requests;
begin
 select * into v_request from public.join_requests where id=p_request_id for update;
 if not found or auth.uid() is null or not private.is_organiser(v_request.group_id) then
   raise exception 'Only the group organiser can approve this request.' using errcode='42501';
 end if;
 if v_request.status='approved' then return; end if;
 if v_request.status<>'pending' then raise exception 'This request is no longer pending.' using errcode='22023'; end if;
 insert into public.memberships(group_id,user_id) values(v_request.group_id,v_request.user_id) on conflict do nothing;
 update public.join_requests set status='approved' where id=p_request_id;
end $$;

revoke all on function public.my_group_overview(), public.group_context(uuid),
 public.create_group(text,uuid), public.request_to_join(text), public.approve_join_request(uuid) from public, anon;
grant execute on function public.my_group_overview(), public.group_context(uuid),
 public.create_group(text,uuid), public.request_to_join(text), public.approve_join_request(uuid) to authenticated;

-- No client INSERT/UPDATE/DELETE grants exist for memberships or spark_states.
-- Contributions and atomic spark passing are a later reviewed migration.
commit;
