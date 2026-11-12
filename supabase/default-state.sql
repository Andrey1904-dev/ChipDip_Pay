-- New users set rates from actual warehouse terms; internship is a separate plan.
alter table public.app_data alter column state set default '{"shifts":[],"settings":{"name":"","rate":0,"pieceRate":0,"goal":65000,"anchor":null,"workDays":2,"restDays":2,"salaryMode":"internship","monthlyNet":65000,"internshipStart":""}}'::jsonb;
