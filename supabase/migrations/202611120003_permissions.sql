-- Override inherited default table grants with explicit column permissions.
revoke all on public.app_data,public.telegram_links,public.public_config,public.telegram_updates from anon,authenticated;
grant select,insert,update,delete on public.app_data to authenticated;
grant select on public.telegram_links to authenticated;
grant insert(user_id,link_code,link_expires_at,reminders,timezone,reminder_time),update(link_code,link_expires_at,reminders,timezone,reminder_time) on public.telegram_links to authenticated;
grant select on public.public_config to authenticated;
revoke all on function public.touch_app_data() from public,anon,authenticated;
