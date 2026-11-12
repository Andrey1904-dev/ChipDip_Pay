-- Encrypted bot credentials are inserted separately, never stored in source.
create or replace function public.smena_bot_config() returns jsonb
language sql security definer set search_path='' as $$
 select coalesce(jsonb_object_agg(name,decrypted_secret),'{}'::jsonb)
 from vault.decrypted_secrets where name in ('smena_bot_token','smena_webhook_secret','smena_reminder_secret','smena_app_url');
$$;
revoke all on function public.smena_bot_config() from public,anon,authenticated;
grant execute on function public.smena_bot_config() to service_role;
