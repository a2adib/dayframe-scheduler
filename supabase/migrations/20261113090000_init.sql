-- Dayframe initial schema (Schema.md v1).
-- Tables, RLS, channels_public view, storage bucket, triggers for the
-- derived post status and Free/Pro plan limits.

-- ── Enums ────────────────────────────────────────────────────────────────────
create type platform as enum ('instagram', 'x', 'linkedin', 'facebook', 'tiktok', 'youtube');
create type post_status as enum ('draft', 'scheduled', 'publishing', 'published', 'failed');
create type schedule_mode as enum ('queue', 'custom', 'now');
create type channel_status as enum ('connected', 'expired', 'revoked');
create type media_kind as enum ('image', 'video');
create type plan_tier as enum ('free', 'pro');

-- ── Tables ───────────────────────────────────────────────────────────────────
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_url text,
  timezone text not null default 'UTC',
  theme text not null default 'system' check (theme in ('system', 'light', 'dark')),
  plan plan_tier not null default 'free',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table channels (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  platform platform not null,
  external_account_id text not null,
  handle text,
  display_name text,
  avatar_url text,
  status channel_status not null default 'connected',
  token_secret_id uuid,            -- reference to Vault secret, never exposed to client
  token_expires_at timestamptz,
  created_at timestamptz not null default now(),
  unique (user_id, platform, external_account_id)
);

create table posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  body text not null default '',
  status post_status not null default 'draft',
  schedule_mode schedule_mode,
  scheduled_at timestamptz,
  published_at timestamptz,
  idempotency_key text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (user_id, idempotency_key)
);

create table post_targets (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references posts(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  channel_id uuid not null references channels(id) on delete cascade,
  body_override text,
  status post_status not null default 'draft',
  scheduled_at timestamptz,
  external_post_id text,
  attempts smallint not null default 0,
  next_attempt_at timestamptz,
  error_message text,
  published_at timestamptz,
  unique (post_id, channel_id)
);
create index on post_targets (status, scheduled_at);
create index on post_targets (user_id, scheduled_at);

create table media_assets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  post_id uuid references posts(id) on delete cascade,
  storage_path text not null,
  kind media_kind not null,
  width int, height int, duration_ms int,
  position smallint not null default 0,
  created_at timestamptz not null default now()
);

create table posting_slots (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  channel_id uuid references channels(id) on delete cascade,  -- null = all channels
  weekday smallint not null check (weekday between 0 and 6),   -- 0 = Sunday
  local_time time not null,
  active boolean not null default true
);

create table metrics_daily (
  id uuid primary key default gen_random_uuid(),
  channel_id uuid not null references channels(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  day date not null,
  followers int, reach int, engagement int, clicks int,
  unique (channel_id, day)
);

create table post_metrics (
  post_target_id uuid primary key references post_targets(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  reach int, likes int, comments int, shares int, clicks int,
  fetched_at timestamptz not null default now()
);

create table notification_prefs (
  user_id uuid primary key references profiles(id) on delete cascade,
  post_published boolean not null default true,
  post_failed boolean not null default true,
  weekly_report boolean not null default false,
  apns_token text
);

create table subscriptions (
  user_id uuid primary key references profiles(id) on delete cascade,
  plan plan_tier not null default 'free',
  provider text,                       -- 'apple'
  original_transaction_id text,
  current_period_end timestamptz,
  status text
);

-- ── Row Level Security (owner-only on every table) ──────────────────────────
alter table profiles enable row level security;
alter table channels enable row level security;
alter table posts enable row level security;
alter table post_targets enable row level security;
alter table media_assets enable row level security;
alter table posting_slots enable row level security;
alter table metrics_daily enable row level security;
alter table post_metrics enable row level security;
alter table notification_prefs enable row level security;
alter table subscriptions enable row level security;

create policy "own rows" on profiles for all
  using (id = auth.uid()) with check (id = auth.uid());
create policy "own rows" on channels for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own rows" on posts for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own rows" on post_targets for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own rows" on media_assets for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own rows" on posting_slots for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own rows" on metrics_daily for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own rows" on post_metrics for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own rows" on notification_prefs for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own rows" on subscriptions for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Client-readable channels without the Vault secret reference.
create view channels_public with (security_invoker = true) as
  select id, user_id, platform, external_account_id, handle, display_name,
         avatar_url, status, token_expires_at, created_at
  from channels;
grant select on channels_public to authenticated;

-- ── updated_at maintenance ───────────────────────────────────────────────────
create or replace function public.touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger posts_touch_updated_at before update on posts
  for each row execute function touch_updated_at();
create trigger profiles_touch_updated_at before update on profiles
  for each row execute function touch_updated_at();

-- ── Derived post status (Schema.md section 4) ────────────────────────────────
create or replace function public.derive_post_status(p_post_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  target_count int;
  published_count int;
  failed_count int;
  publishing_count int;
  parent_scheduled_at timestamptz;
begin
  select count(*), count(*) filter (where status = 'published'),
         count(*) filter (where status = 'failed'),
         count(*) filter (where status = 'publishing'),
         max(scheduled_at)
  into target_count, published_count, failed_count, publishing_count, parent_scheduled_at
  from post_targets where post_id = p_post_id;

  if target_count = 0 then
    update posts set status = case when scheduled_at is null then 'draft'::post_status else 'scheduled'::post_status end
    where id = p_post_id;
  elsif publishing_count > 0 then
    update posts set status = 'publishing'::post_status where id = p_post_id;
  elsif failed_count > 0 then
    update posts set status = 'failed'::post_status where id = p_post_id;
  elsif published_count = target_count then
    update posts set status = 'published'::post_status where id = p_post_id;
  else
    update posts
    set status = case when scheduled_at is null then 'draft'::post_status else 'scheduled'::post_status end
    where id = p_post_id;
  end if;
end;
$$;

create or replace function public.derive_post_status_trigger() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform derive_post_status(coalesce(new.post_id, old.post_id));
  return null;
end;
$$;

create trigger post_targets_derive_status
  after insert or update or delete on post_targets
  for each row execute function derive_post_status_trigger();

-- ── Plan limits (Schema.md section 6): Free = 3 channels, 10 scheduled
-- targets per channel ─────────────────────────────────────────────────────────
create or replace function public.enforce_channel_plan_limit() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  user_plan plan_tier;
  channel_count int;
begin
  select plan into user_plan from profiles where id = new.user_id;
  if user_plan = 'free' then
    select count(*) into channel_count from channels where user_id = new.user_id;
    if channel_count >= 3 then
      raise exception 'PLAN_LIMIT: Free plan connects up to 3 channels'
        using errcode = 'P0001';
    end if;
  end if;
  return new;
end;
$$;

create trigger channels_plan_limit before insert on channels
  for each row execute function enforce_channel_plan_limit();

create or replace function public.enforce_target_plan_limit() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  user_plan plan_tier;
  scheduled_count int;
begin
  select plan into user_plan from profiles where id = new.user_id;
  if user_plan = 'free' and new.status = 'scheduled' then
    select count(*) into scheduled_count
    from post_targets
    where channel_id = new.channel_id and status = 'scheduled';
    if scheduled_count >= 10 then
      raise exception 'PLAN_LIMIT: Free plan schedules up to 10 posts per channel'
        using errcode = 'P0001';
    end if;
  end if;
  return new;
end;
$$;

create trigger post_targets_plan_limit before insert on post_targets
  for each row execute function enforce_target_plan_limit();

-- ── New auth user → profile ──────────────────────────────────────────────────
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'display_name', split_part(new.email, '@', 1))
  );
  return new;
end;
$$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function handle_new_user();

-- ── Storage: private media bucket, owner-folder policies ─────────────────────
insert into storage.buckets (id, name, public)
values ('media', 'media', false)
on conflict (id) do nothing;

create policy "own media folder" on storage.objects for all
  using (bucket_id = 'media' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'media' and (storage.foldername(name))[1] = auth.uid()::text);
