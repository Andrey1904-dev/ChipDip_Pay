-- Apply after deploying the function and creating the two Vault secrets:
-- smena_reminder_url = https://usxclvxtmtiwexkgsxyp.supabase.co/functions/v1/telegram-bot/remind
-- smena_reminder_secret = same value as Edge Function REMINDER_SECRET.
create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;
select cron.schedule('smena-workday-reminders', '*/5 * * * *', $$
 select net.http_post(
  url := (select decrypted_secret from vault.decrypted_secrets where name='smena_reminder_url'),
  headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name='smena_reminder_secret')),
  body := '{}'::jsonb
 );
$$);
select cron.schedule('smena-prune-telegram-updates','0 2 * * *', $$ delete from public.telegram_updates where created_at < now() - interval '7 days'; $$);
