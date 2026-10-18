-- Dev only. Exact disposable users created by the concurrency setup.
-- First remove the scoped synthetic object via the Storage UI/API. Never bypass
-- Supabase's prohibition on direct Storage-table deletion.
begin;
create temporary table ff_cleanup_users as select id from auth.users
 where email in ('ff-history-concurrency-owner@example.invalid','ff-history-concurrency-other@example.invalid');
create temporary table ff_cleanup_workspaces as select id from ff_private.workspaces
 where owner_id in (select id from ff_cleanup_users);
do $$ begin
 if exists(select 1 from storage.objects where bucket_id='farrierflow-photos'
  and split_part(name,'/',1) in (select id::text from ff_cleanup_workspaces)) then
  raise exception 'Remove disposable objects through Storage UI/API first';
 end if;
end $$;
delete from ff_private.photo_manifest where workspace_id in (select id from ff_cleanup_workspaces);
delete from ff_private.commits where workspace_id in (select id from ff_cleanup_workspaces);
delete from ff_private.records where workspace_id in (select id from ff_cleanup_workspaces);
delete from ff_private.devices where workspace_id in (select id from ff_cleanup_workspaces);
delete from ff_private.memberships where workspace_id in (select id from ff_cleanup_workspaces);
delete from ff_private.workspaces where id in (select id from ff_cleanup_workspaces);
delete from auth.sessions where user_id in (select id from ff_cleanup_users);
delete from auth.users where id in (select id from ff_cleanup_users);
commit;
select 'PASS: exact disposable concurrency fixtures removed' as result;
