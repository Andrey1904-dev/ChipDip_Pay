-- New accounts choose their own schedule; no fixed start date.
alter table public.app_data alter column state set default '{"shifts":[],"settings":{"name":"","rate":350,"pieceRate":5,"goal":80000,"anchor":null,"workDays":2,"restDays":2}}'::jsonb;
