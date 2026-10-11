begin;

create or replace function public.leave_group(p_group_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_holder uuid;
  v_role text;
begin
  if v_user is null then
    raise exception 'Sign in before leaving a group.' using errcode = '42501';
  end if;
  -- Keep the holder stable while checking and removing membership.
  select holder_id into v_holder from public.spark_states
    where group_id = p_group_id for update;
  -- Match approval's request-before-membership lock order.
  perform 1 from public.join_requests
    where group_id = p_group_id and user_id = v_user for update;
  select role into v_role from public.memberships
    where group_id = p_group_id and user_id = v_user for update;
  if not found then return; end if;
  if v_role = 'organiser' then
    raise exception 'Organiser handover is needed before you can leave. Handover is not available yet.' using errcode = '22023';
  end if;
  if v_holder = v_user then
    raise exception 'Pass the spark to another member before leaving.' using errcode = '22023';
  end if;
  -- Allow a future invitation to create a fresh request, requiring approval again.
  delete from public.join_requests where group_id = p_group_id and user_id = v_user;
  delete from public.memberships where group_id = p_group_id and user_id = v_user;
end;
$$;
revoke all on function public.leave_group(uuid) from public, anon;
grant execute on function public.leave_group(uuid) to authenticated;

commit;
