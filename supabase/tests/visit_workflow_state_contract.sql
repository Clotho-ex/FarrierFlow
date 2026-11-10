-- Synthetic progress/finalization graph; no customer records, always rolled back.
begin;
create temporary table ff_workflow_workspace as select gen_random_uuid() as id;
insert into ff_private.workspaces(id, owner_id) select id, gen_random_uuid() from ff_workflow_workspace;
create temporary table ff_workflow_ids(label text primary key, id uuid not null);
insert into ff_workflow_ids select label, gen_random_uuid() from unnest(array[
  'client','barn','horse','service','appointment','appointmentHorse','visit','visitHorse','workItem'
]) label;
insert into ff_private.records(workspace_id,id,kind,fields,revision)
select (select id from ff_workflow_workspace), i.id, i.label, x.fields, 1
from ff_workflow_ids i cross join lateral (
  select case i.label
  when 'client' then jsonb_build_object('name','Workflow Client','phone',null,'email',null,'notes',null)
  when 'barn' then jsonb_build_object('name','Workflow Barn','address',null,'contactNotes',null)
  when 'horse' then jsonb_build_object('name','Burger','safetyNotes',null,'appointmentIntervalWeeks',6,
    'client',(select id::text from ff_workflow_ids where label='client'),
    'currentBarn',(select id::text from ff_workflow_ids where label='barn'),'defaultService',null)
  when 'service' then jsonb_build_object('name','Brushing','defaultAmountMinorUnits',10000,'currencyCode','USD','isArchived',false)
  when 'appointment' then jsonb_build_object('startDate','100.0','notes',null,'expectedDurationMinutes',null,
    'barn',(select id::text from ff_workflow_ids where label='barn'))
  when 'appointmentHorse' then jsonb_build_object(
    'appointment',(select id::text from ff_workflow_ids where label='appointment'),
    'horse',(select id::text from ff_workflow_ids where label='horse'),'plannedService',
    (select id::text from ff_workflow_ids where label='service'))
  when 'visit' then jsonb_build_object('startedAt','100.0','completedAt',null,
    'serviceLocationNameSnapshot','Workflow Barn','serviceLocationAddressSnapshot',null,
    'appointment',(select id::text from ff_workflow_ids where label='appointment'),
    'barn',(select id::text from ff_workflow_ids where label='barn'))
  when 'visitHorse' then jsonb_build_object('outcomeRawValue','pending','workNotes','Waiting for the owner.',
    'visit',(select id::text from ff_workflow_ids where label='visit'),
    'horse',(select id::text from ff_workflow_ids where label='horse'))
  when 'workItem' then jsonb_build_object('billingHoldID',null,'serviceNameSnapshot','Brushing',
    'amountMinorUnits',10000,'currencyCode','USD','service',
    (select id::text from ff_workflow_ids where label='service'),
    'visitHorse',(select id::text from ff_workflow_ids where label='visitHorse'))
  end as fields
) x;
select ff_private.validate_graph((select id from ff_workflow_workspace));
do $$
declare workspace uuid := (select id from ff_workflow_workspace); work_before jsonb;
begin
  select fields into work_before from ff_private.records where workspace_id=workspace and kind='workItem';
  update ff_private.records set fields=jsonb_set(fields,'{outcomeRawValue}','"notServiced"')
    where workspace_id=workspace and kind='visitHorse';
  perform ff_private.validate_graph(workspace);
  if work_before is distinct from (select fields from ff_private.records where workspace_id=workspace and kind='workItem')
    then raise exception 'Outcome change altered recorded work'; end if;
  begin
    update ff_private.records set fields=jsonb_set(fields,'{completedAt}','"200.0"')
      where workspace_id=workspace and kind='visit';
    perform ff_private.validate_graph(workspace);
    raise exception 'Conflicting Not Serviced work was finalized';
  exception when check_violation then null;
  end;
  delete from ff_private.records where workspace_id=workspace and kind='workItem';
  update ff_private.records set fields=jsonb_set(fields,'{workNotes}','"Horse could not be handled safely."')
    where workspace_id=workspace and kind='visitHorse';
  update ff_private.records set fields=jsonb_set(fields,'{completedAt}','"200.0"')
    where workspace_id=workspace and kind='visit';
  perform ff_private.validate_graph(workspace);
  begin
    update ff_private.records set fields=jsonb_set(fields,'{outcomeRawValue}','"pending"')
      where workspace_id=workspace and kind='visitHorse';
    perform ff_private.validate_graph(workspace);
    raise exception 'Unresolved horse was finalized';
  exception when check_violation then null;
  end;
  begin
    update ff_private.records set fields=jsonb_set(fields,'{outcomeRawValue}','"serviced"')
      where workspace_id=workspace and kind='visitHorse';
    perform ff_private.validate_graph(workspace);
    raise exception 'Serviced horse without performed services was finalized';
  exception when check_violation then null;
  end;
end $$;
select 'PASS: progress, outcome conflicts and attended Not Serviced completion' as result;
rollback;
