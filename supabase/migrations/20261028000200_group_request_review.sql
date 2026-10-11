-- Add the organiser-only list used by Members and requests.
-- Run this file after the backend foundation migration.
begin;

create or replace function public.list_group_requests(p_group_id uuid) returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
begin
  if auth.uid() is null or not private.is_organiser(p_group_id) then
    raise exception 'Only the group organiser can view join requests.' using errcode='42501';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('id',r.id,'display_name',p.display_name)
      order by r.created_at,r.id)
    from public.join_requests r
    join public.profiles p on p.id=r.user_id
    where r.group_id=p_group_id and r.status='pending'
  ),'[]'::jsonb);
end $$;

revoke all on function public.list_group_requests(uuid) from public, anon;
grant execute on function public.list_group_requests(uuid) to authenticated;
commit;
