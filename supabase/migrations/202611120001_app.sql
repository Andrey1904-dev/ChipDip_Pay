create table if not exists public.app_data (
 user_id uuid primary key references auth.users(id) on delete cascade,
 state jsonb not null default '{"shifts":[],"settings":{"rate":350,"pieceRate":5,"goal":80000,"anchor":"2026-11-13"}}',
 version integer not null default 1 check (version > 0),
 updated_at timestamptz not null default now(),
 constraint state_shape check(jsonb_typeof(state->'shifts')='array' and jsonb_typeof(state->'settings')='object')
);
alter table public.app_data enable row level security;
create policy "Own income data" on public.app_data for all to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
grant select,insert,update,delete on public.app_data to authenticated;
create table if not exists public.telegram_links (
 user_id uuid primary key references auth.users(id) on delete cascade,
 chat_id bigint unique,
 link_code text unique,
 link_expires_at timestamptz,
 reminders boolean not null default false,
 timezone text not null default 'Asia/Yekaterinburg',
 reminder_time time not null default '08:00',
 last_reminded date
);
alter table public.telegram_links enable row level security;
create policy "Read own Telegram link" on public.telegram_links for select to authenticated using ((select auth.uid())=user_id);
create policy "Create own Telegram link" on public.telegram_links for insert to authenticated with check ((select auth.uid())=user_id and chat_id is null and last_reminded is null);
create policy "Update own Telegram preferences" on public.telegram_links for update to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
grant select on public.telegram_links to authenticated;
grant insert(user_id,link_code,link_expires_at,reminders,timezone,reminder_time),update(link_code,link_expires_at,reminders,timezone,reminder_time) on public.telegram_links to authenticated;
create table if not exists public.public_config(key text primary key,value text not null);
alter table public.public_config enable row level security;
create policy "Public bot username" on public.public_config for select to authenticated using(key='bot_username');
grant select on public.public_config to authenticated;
create table if not exists public.telegram_updates(update_id bigint primary key,created_at timestamptz not null default now());
alter table public.telegram_updates enable row level security;
create or replace function public.touch_app_data() returns trigger language plpgsql set search_path='' as $$ begin new.updated_at=now(); return new; end $$;
create trigger touch_app_data before update on public.app_data for each row execute function public.touch_app_data();
