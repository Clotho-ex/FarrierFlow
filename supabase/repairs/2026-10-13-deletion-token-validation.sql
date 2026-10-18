-- PostgreSQL repetition bounds cannot exceed 255; keep envelope length bounded separately.
begin;
create or replace function ff_private.queue_deletion(p_account uuid, p_session uuid, p_workspace uuid,
  p_operation uuid, p_receipt_hash text, p_token jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare w ff_private.workspaces%rowtype; job ff_private.deletion_jobs%rowtype;
begin
  if p_account is null or p_session is null or p_workspace is null or p_operation is null
     or p_receipt_hash is null or p_receipt_hash !~ '^[a-f0-9]{64}$'
     or p_token is null or jsonb_typeof(p_token) <> 'object'
     or (select count(*) from jsonb_object_keys(p_token)) <> 3
     or p_token->>'version' is distinct from '1'
     or coalesce(p_token->>'iv','') !~ '^[A-Za-z0-9_-]{16}$'
     or length(coalesce(p_token->>'ciphertext','')) not between 23 and 21867
     or coalesce(p_token->>'ciphertext','') !~ '^[A-Za-z0-9_-]+$' then
    raise exception 'Invalid deletion request' using errcode = '22023';
  end if;
  select * into w from ff_private.workspaces where id = p_workspace for update;
  if w.id is null or w.owner_id is distinct from p_account then
    raise exception 'Owner required' using errcode = '42501';
  end if;
  select * into job from ff_private.deletion_jobs where id = p_operation;
  if found then
    if job.user_id is distinct from p_account or job.workspace_id is distinct from p_workspace
       or job.receipt_hash is distinct from p_receipt_hash then
      raise exception 'Deletion identity reused' using errcode = '22023';
    end if;
    return jsonb_build_object('jobID', job.id, 'state', 'pending');
  end if;
  if w.deleting or not exists(select 1 from auth.sessions where id = p_session and user_id = p_account)
     or not exists(select 1 from ff_private.memberships where workspace_id = p_workspace
       and user_id = p_account and role = 'owner' and revoked_at is null)
     or (select count(*) from ff_private.memberships where workspace_id = p_workspace and revoked_at is null) <> 1 then
    raise exception 'Active solo owner session required' using errcode = '42501';
  end if;
  insert into ff_private.deletion_jobs(id, workspace_id, user_id, receipt_hash, encrypted_apple_token)
    values(p_operation, p_workspace, p_account, p_receipt_hash, p_token);
  update ff_private.workspaces set deleting = true where id = p_workspace;
  update ff_private.memberships set revoked_at = now() where workspace_id = p_workspace;
  return jsonb_build_object('jobID', p_operation, 'state', 'pending');
end $$;

commit;
