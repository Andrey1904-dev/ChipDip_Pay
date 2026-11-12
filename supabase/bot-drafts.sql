-- Only the server bot can access in-progress conversations.
create table if not exists public.telegram_drafts (
 chat_id bigint primary key,
 user_id uuid not null references auth.users(id) on delete cascade,
 state jsonb not null,
 version integer not null default 1,
 expires_at timestamptz not null default (now()+interval '1 hour')
);
alter table public.telegram_drafts enable row level security;
revoke all on public.telegram_drafts from anon,authenticated;
grant all on public.telegram_drafts to service_role;
