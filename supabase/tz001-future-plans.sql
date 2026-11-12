-- Preserve all legacy fields and annotate only future records, never past work.
update public.app_data a set state=jsonb_set(a.state,'{shifts}',(
 select coalesce(jsonb_agg(case when (x->>'date')>(now() at time zone 'Asia/Yekaterinburg')::date::text and not(x?'status') then x||'{"status":"planned"}'::jsonb else x end),'[]'::jsonb)
 from jsonb_array_elements(a.state->'shifts') x
)),version=a.version+1
where exists(select 1 from jsonb_array_elements(a.state->'shifts') x where (x->>'date')>(now() at time zone 'Asia/Yekaterinburg')::date::text and not(x?'status'));
