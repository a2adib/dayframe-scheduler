# Schema: Dayframe

Postgres (Supabase). All timestamps are `timestamptz` in UTC. All tables have RLS enabled with owner-only access unless noted.

## 1. Enums
```sql
create type platform as enum ('instagram','x','linkedin','facebook','tiktok','youtube');
create type post_status as enum ('draft','scheduled','publishing','published','failed');
create type schedule_mode as enum ('queue','custom','now');
create type channel_status as enum ('connected','expired','revoked');
create type media_kind as enum ('image','video');
create type plan_tier as enum ('free','pro');
```

## 2. Tables
```sql
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_url text,
  timezone text not null default 'UTC',
  theme text not null default 'system' check (theme in ('system','light','dark')),
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
```

## 3. Row Level Security (pattern)
```sql
alter table posts enable row level security;
create policy "own rows" on posts
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
```
Apply the same pattern to every table with a `user_id` column. `channels.token_secret_id` must be excluded from client-readable views (expose a `channels_public` view without it).

## 4. Derived Post Status
`posts.status` is updated by a trigger from its `post_targets`:
- all published → `published`
- any failed and none in progress → `failed`
- any publishing → `publishing`
- otherwise `scheduled` (or `draft` if not scheduled)

## 5. Storage
Bucket `media` (private). Path: `{user_id}/{post_id}/{uuid}.{ext}`. Policies limit access to the owner's folder. Signed URLs for display.

## 6. Plan Limits (enforced by trigger or function)
Free: max 3 channels per user, max 10 `scheduled` targets per channel.

## 7. Swift Model Mapping
`Profile`, `Channel`, `Post` (with `[PostTarget]`, `[MediaAsset]`), `PostingSlot`, `DailyMetrics`, `PostMetrics`, `NotificationPrefs`. Use `Codable` with snake_case keys via `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase`. Enums mirror section 1 exactly.

## 8. Migrations
One file per change in `/supabase/migrations/YYYYMMDDHHMM_name.sql`. Never edit applied migrations; add new ones.

## 9. Related Docs
TRD.md for engine behavior, UI_Spec.md for how data is displayed.
