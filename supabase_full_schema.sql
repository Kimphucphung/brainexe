-- =====================================================
-- brain.exe Supabase full schema
-- Run this once in the Supabase SQL Editor for the project used by index.html.
-- Project URL currently in code: https://zjjfxsyyzypvyactnyry.supabase.co
-- This file is idempotent: safe to run again.
-- =====================================================

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text unique not null,
  name text,
  plan text not null default 'starter' check (plan in ('starter', 'busy', 'royal')),
  subscription_status text default 'inactive' check (subscription_status in ('inactive', 'active', 'cancelled', 'past_due')),
  subscription_end timestamptz,
  created_at timestamptz default now() not null,
  updated_at timestamptz default now() not null
);

create table if not exists public.app_data (
  user_id uuid primary key references auth.users(id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz default now() not null
);

create table if not exists public.waitlist (
  id uuid primary key default gen_random_uuid(),
  email text unique not null,
  source text,
  interested_plan text,
  created_at timestamptz default now() not null
);

create table if not exists public.analytics_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  session_id text not null,
  event text not null,
  path text,
  referrer text,
  properties jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.app_data enable row level security;
alter table public.waitlist enable row level security;
alter table public.analytics_events enable row level security;

drop policy if exists "users can view own profile" on public.profiles;
create policy "users can view own profile"
on public.profiles for select
using (auth.uid() = id);

drop policy if exists "users can update own profile" on public.profiles;
create policy "users can update own profile"
on public.profiles for update
using (auth.uid() = id);

drop policy if exists "users can insert own profile" on public.profiles;
create policy "users can insert own profile"
on public.profiles for insert
with check (auth.uid() = id);

drop policy if exists "users can view own data" on public.app_data;
create policy "users can view own data"
on public.app_data for select
using (auth.uid() = user_id);

drop policy if exists "users can update own data" on public.app_data;
create policy "users can update own data"
on public.app_data for update
using (auth.uid() = user_id);

drop policy if exists "users can insert own data" on public.app_data;
create policy "users can insert own data"
on public.app_data for insert
with check (auth.uid() = user_id);

drop policy if exists "users can delete own data" on public.app_data;
create policy "users can delete own data"
on public.app_data for delete
using (auth.uid() = user_id);

drop policy if exists "anyone can join waitlist" on public.waitlist;
create policy "anyone can join waitlist"
on public.waitlist for insert
with check (true);

drop policy if exists "clients can insert analytics events" on public.analytics_events;
create policy "clients can insert analytics events"
on public.analytics_events for insert
with check (user_id is null or auth.uid() = user_id);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, name)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1))
  )
  on conflict (id) do nothing;

  insert into public.app_data (user_id, data)
  values (new.id, '{}'::jsonb)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists app_data_updated_at on public.app_data;
create trigger app_data_updated_at
before update on public.app_data
for each row execute procedure public.set_updated_at();

drop trigger if exists profiles_updated_at on public.profiles;
create trigger profiles_updated_at
before update on public.profiles
for each row execute procedure public.set_updated_at();

create index if not exists analytics_events_created_at_idx
on public.analytics_events (created_at desc);

create index if not exists analytics_events_event_idx
on public.analytics_events (event);

create index if not exists analytics_events_user_id_idx
on public.analytics_events (user_id);

-- Quick checks after running:
-- select table_name from information_schema.tables where table_schema = 'public' order by table_name;
-- select event, count(*) from public.analytics_events group by event order by count(*) desc;
