begin;
select set_config('chipdip.test_a',gen_random_uuid()::text,true);
select set_config('chipdip.test_b',gen_random_uuid()::text,true);
insert into auth.users(id) values(current_setting('chipdip.test_a')::uuid),(current_setting('chipdip.test_b')::uuid);
set local role authenticated;
select set_config('request.jwt.claim.sub',current_setting('chipdip.test_a'),true);
do $test$
declare ops jsonb; result jsonb;
begin
 ops:='[{"opId":"tz001-test-payout","collection":"payments","id":"p1","base":null,"value":{"id":"p1","date":"2026-11-10","period":"2026-11","amount":15000,"type":"advance","comment":"isolated test"}}]'::jsonb;
 perform public.apply_chipdip_ops(ops);
 result:=public.apply_chipdip_ops(ops);
 if jsonb_array_length(result->'state'->'payments')<>1 or (result->>'version')::int<>2 then raise exception 'idempotency check failed';end if;
 begin
  perform public.apply_chipdip_ops('[]',current_setting('chipdip.test_b')::uuid);
  raise exception 'cross-user write accepted';
 exception when others then if sqlerrm<>'forbidden' then raise;end if;end;
 begin
  perform public.apply_chipdip_ops('[{"opId":"tz001-test-conflict","collection":"payments","id":"p1","base":null,"value":{"id":"p1","date":"2026-11-10","period":"2026-11","amount":999,"type":"salary"}}]');
  raise exception 'stale edit accepted';
 exception when others then if sqlerrm not like 'conflict:%' then raise;end if;end;
 if (select count(*) from public.app_data)<>1 or (select count(*) from public.chipdip_operations)<>1 then raise exception 'RLS own records failed';end if;
end;$test$;
reset role;
set local role service_role;
do $test$ begin
 perform public.apply_chipdip_ops('[{"opId":"tz001-bot-mark","collection":"calendar","id":"2026-11-02","base":null,"value":{"id":"2026-11-02","date":"2026-11-02","type":"normal","worked":true}}]',current_setting('chipdip.test_a')::uuid);
end;$test$;
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub',current_setting('chipdip.test_b'),true);
do $test$ begin
 if (select count(*) from public.app_data)<>0 or (select count(*) from public.chipdip_operations)<>0 then raise exception 'Cross-user RLS isolation failed';end if;
 perform public.apply_chipdip_ops('[{"opId":"tz001-test-payout","collection":"payments","id":"p1","base":null,"value":{"id":"p1","date":"2026-11-10","period":"2026-11","amount":123,"type":"other"}}]');
end;$test$;
reset role;
do $test$ declare s jsonb;begin
 select state into s from public.app_data where user_id=current_setting('chipdip.test_a')::uuid;
 if (s->'payments'->0->>'amount')::numeric<>15000 or jsonb_array_length(s->'calendar')<>1 then raise exception 'Bot/PWA merge failed';end if;
 update public.app_data set state=state-'payments'-'calendar' where user_id=current_setting('chipdip.test_a')::uuid;
 select state into s from public.app_data where user_id=current_setting('chipdip.test_a')::uuid;
 if jsonb_array_length(s->'payments')<>1 or jsonb_array_length(s->'calendar')<>1 then raise exception 'Legacy client preservation failed';end if;
end;$test$;
select 'RLS, owner binding, bot/PWA merge, idempotency, stale-edit conflict and legacy-client preservation: passed' as result;
rollback;
