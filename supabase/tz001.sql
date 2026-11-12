-- Additive migration: no existing account or user record is removed.
create table if not exists public.chipdip_operations (
 user_id uuid not null references auth.users(id) on delete cascade,
 op_id text not null,
 fingerprint text not null,
 created_at timestamptz not null default now(),
 primary key(user_id,op_id)
);
alter table public.chipdip_operations enable row level security;
create policy "Own operation journal" on public.chipdip_operations for all to authenticated
 using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
revoke all on public.chipdip_operations from anon,authenticated;
grant select,insert on public.chipdip_operations to authenticated;
grant all on public.chipdip_operations to service_role;

create or replace function public.apply_chipdip_ops(p_ops jsonb,p_user uuid default null,p_force boolean default false)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare
 uid uuid; s jsonb; v integer; op jsonb; coll text; rid text; current_value jsonb; new_value jsonb;
 previous_fingerprint text; fingerprint text; changed boolean:=false;
begin
 uid:=auth.uid();
 if current_user='service_role' then uid:=p_user;
 elsif p_user is not null and p_user is distinct from uid then raise exception 'forbidden'; end if;
 if uid is null then raise exception 'unauthorized'; end if;
 if jsonb_typeof(p_ops) is distinct from 'array' or jsonb_array_length(p_ops)>250 then raise exception 'invalid operations'; end if;
 insert into public.app_data(user_id) values(uid) on conflict(user_id) do nothing;
 select state,version into s,v from public.app_data where user_id=uid for update;
 if not found then raise exception 'forbidden'; end if;
 for coll in select unnest(array['calendar','payments','adjustments','monthlyApprovals','shifts']) loop
  if jsonb_typeof(s->coll) is distinct from 'array' then s:=jsonb_set(s,array[coll],'[]'::jsonb); end if;
 end loop;
 for op in select value from jsonb_array_elements(p_ops) loop
  coll:=op->>'collection';rid:=op->>'id';new_value:=op->'value';
  if coll is null or coll not in ('calendar','payments','adjustments','monthlyApprovals','shifts','settings')
   or rid is null or length(rid)>120 or rid in ('__proto__','constructor','prototype')
   or coalesce(length(op->>'opId'),0) not between 1 and 160 or not(op?'base') or not(op?'value') then raise exception 'invalid operation'; end if;
  fingerprint:=md5(op::text);
  select o.fingerprint into previous_fingerprint from public.chipdip_operations o where o.user_id=uid and o.op_id=op->>'opId';
  if found then if previous_fingerprint<>fingerprint then raise exception 'idempotency key reused'; end if;continue; end if;
  if coll='settings' then current_value:=coalesce(s->'settings'->rid,'null'::jsonb);
  else select value into current_value from jsonb_array_elements(s->coll) where value->>'id'=rid limit 1;current_value:=coalesce(current_value,'null'::jsonb);end if;
  if not p_force and current_value is distinct from op->'base' and current_value is distinct from new_value then
   raise exception 'conflict:%:%',coll,rid;
  end if;
  if new_value<>'null'::jsonb and coll<>'settings' then
   if jsonb_typeof(new_value) is distinct from 'object' or new_value->>'id' is distinct from rid then raise exception 'invalid record';end if;
   if coll in ('calendar','payments','adjustments','shifts') and (coalesce(new_value->>'date','')!~'^\d{4}-\d{2}-\d{2}$') then raise exception 'invalid date';end if;
   if coll='calendar' and (rid is distinct from new_value->>'date' or coalesce(new_value->>'type','') not in ('normal','extra','missed','off') or jsonb_typeof(new_value->'worked') is distinct from 'boolean') then raise exception 'invalid calendar mark';end if;
   if coll in ('payments','adjustments') then
    if jsonb_typeof(new_value->'amount') is distinct from 'number' or (new_value->>'amount')::numeric<0 or (new_value->>'amount')::numeric>1000000000
      or coalesce(new_value->>'period','')!~'^\d{4}-(0[1-9]|1[0-2])$' then raise exception 'invalid money record';end if;
    if coll='payments' and coalesce(new_value->>'type','') not in ('advance','salary','other') then raise exception 'invalid payment type';end if;
    if coll='adjustments' and coalesce(new_value->>'type','') not in ('bonus','deduction') then raise exception 'invalid adjustment type';end if;
   end if;
   if coll='monthlyApprovals' and (rid!~'^\d{4}-(0[1-9]|1[0-2])$' or jsonb_typeof(new_value->'amount') is distinct from 'number' or (new_value->>'amount')::numeric<0) then raise exception 'invalid accrual confirmation';end if;
  end if;
  if coll='settings' then
   if new_value='null'::jsonb then s:=s#-array['settings',rid];else s:=jsonb_set(s,array['settings',rid],new_value,true);end if;
  else
   s:=jsonb_set(s,array[coll],coalesce((select jsonb_agg(value) from jsonb_array_elements(s->coll) where value->>'id' is distinct from rid),'[]'::jsonb) || case when new_value='null'::jsonb then '[]'::jsonb else jsonb_build_array(new_value) end);
  end if;
  insert into public.chipdip_operations(user_id,op_id,fingerprint) values(uid,op->>'opId',fingerprint);changed:=true;
 end loop;
 if changed then update public.app_data set state=s,version=v+1 where user_id=uid returning version into v;end if;
 return jsonb_build_object('state',s,'version',v);
end;$$;
revoke all on function public.apply_chipdip_ops(jsonb,uuid,boolean) from public,anon;
grant execute on function public.apply_chipdip_ops(jsonb,uuid,boolean) to authenticated,service_role;

-- An old installed client must not remove the new ledgers by omitting them.
create or replace function public.touch_app_data() returns trigger language plpgsql set search_path='' as $$
declare k text;begin
 foreach k in array array['calendar','payments','adjustments','monthlyApprovals'] loop
  if not(new.state?k) and old.state?k then new.state:=jsonb_set(new.state,array[k],old.state->k);end if;
 end loop;
 new.updated_at=now();return new;
end;$$;
revoke all on function public.touch_app_data() from public,anon,authenticated;
