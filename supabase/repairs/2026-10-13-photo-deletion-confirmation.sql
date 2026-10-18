-- Dev-only repair. A delete can locate a tombstone; downloads still cannot.
begin;
alter policy ff_photo_read on storage.objects to authenticated
using (bucket_id = 'farrierflow-photos' and (
  ff_private.photo_allowed(name) or (
    storage.allow_any_operation(array['object.delete', 'object.delete_many'])
    and ff_private.photo_allowed(name, true)
  )
));
create or replace function ff_private.photo_delete_confirm(p_workspace uuid, p_photo uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  perform ff_private.require_access(p_workspace);
  perform 1 from ff_private.workspaces where id = p_workspace for update;
  perform ff_private.require_access(p_workspace);
  if not exists (
    select 1 from ff_private.records where workspace_id = p_workspace and id = p_photo
      and kind = 'photograph' and fields is null
  ) or exists (
    select 1 from storage.objects where bucket_id = 'farrierflow-photos'
      and name = p_workspace::text || '/' || p_photo::text || '.jpg'
  ) then raise exception 'Photo deletion not verified' using errcode = '23514'; end if;
  delete from ff_private.photo_manifest where workspace_id = p_workspace and id = p_photo;
  return jsonb_build_object('id', p_photo, 'deleted', true);
end $$;
create or replace function public.ff_photo_delete_confirm(p_workspace uuid, p_photo uuid)
returns jsonb language sql security invoker set search_path = '' as $$
  select ff_private.photo_delete_confirm(p_workspace, p_photo)
$$;
revoke all on function ff_private.photo_delete_confirm(uuid,uuid),
  public.ff_photo_delete_confirm(uuid,uuid) from public, anon, authenticated;
grant execute on function ff_private.photo_delete_confirm(uuid,uuid),
  public.ff_photo_delete_confirm(uuid,uuid) to authenticated;
commit;
