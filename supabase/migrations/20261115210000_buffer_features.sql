-- ── Buffer-Style Features Migration ──────────────────────────────────────────
-- 1. Add threads to platform enum
-- 2. Add is_paused to channels
-- 3. Update channels_public view
-- 4. Add first_comment to posts and post_targets
-- 5. Create ideas table with RLS and updated_at trigger
-- 6. Create engagement_items table with RLS
-- 7. Update claim_due_targets to skip paused channels and return first_comment

-- 1. Platform enum extension
alter type platform add value if not exists 'threads';

-- 2. Channel Pause Queue toggle
alter table channels add column if not exists is_paused boolean not null default false;

-- 3. Update channels_public view to expose is_paused (without token secrets)
drop view if exists channels_public;
create view channels_public with (security_invoker = true) as
  select id, user_id, platform, external_account_id, handle, display_name,
         avatar_url, status, is_paused, token_expires_at, created_at
  from channels;
grant select on channels_public to authenticated;

-- 4. First Comment Automation
alter table posts add column if not exists first_comment text;
alter table post_targets add column if not exists first_comment text;

-- 5. Ideas Board (Kanban Content Bank)
create table if not exists ideas (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  title text not null default '',
  notes text not null default '',
  stage text not null default 'raw' check (stage in ('raw', 'drafting', 'ready', 'converted')),
  tags text[] not null default '{}',
  link text,
  media_urls text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table ideas enable row level security;
create policy "own rows" on ideas for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create trigger ideas_touch_updated_at before update on ideas
  for each row execute function touch_updated_at();

-- 6. Unified Community Engagement Items
create table if not exists engagement_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  channel_id uuid not null references channels(id) on delete cascade,
  post_id uuid references posts(id) on delete set null,
  author_name text not null,
  author_handle text,
  author_avatar_url text,
  content text not null,
  platform platform not null,
  is_replied boolean not null default false,
  is_starred boolean not null default false,
  reply_text text,
  replied_at timestamptz,
  created_at timestamptz not null default now()
);

alter table engagement_items enable row level security;
create policy "own rows" on engagement_items for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create index if not exists engagement_items_user_idx on engagement_items(user_id, created_at desc);
create index if not exists engagement_items_channel_idx on engagement_items(channel_id);

-- 7. Update claim_due_targets to respect channel pause queue and return first_comment
-- The return type gains a column, which `create or replace` cannot do, so drop first.
drop function if exists public.claim_due_targets(int);
create function public.claim_due_targets(p_limit int default 10)
returns table (
  target_id uuid,
  post_id uuid,
  user_id uuid,
  channel_id uuid,
  platform platform,
  body text,
  body_override text,
  first_comment text,
  attempts smallint,
  media jsonb
)
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  return query
  with claimed as (
    select pt.id
    from post_targets pt
    join channels c on c.id = pt.channel_id
    join posts p on p.id = pt.post_id
    where pt.status = 'scheduled'
      and pt.scheduled_at <= now()
      and (pt.next_attempt_at is null or pt.next_attempt_at <= now())
      and c.status = 'connected'
      and c.is_paused = false
      and p.deleted_at is null
    order by pt.scheduled_at
    limit p_limit
    for update of pt skip locked
  )
  update post_targets pt
  set status = 'publishing'
  from claimed c, posts p, channels ch
  where pt.id = c.id
    and p.id = pt.post_id
    and ch.id = pt.channel_id
  returning
    pt.id,
    pt.post_id,
    pt.user_id,
    pt.channel_id,
    ch.platform,
    p.body,
    pt.body_override,
    coalesce(pt.first_comment, p.first_comment) as first_comment,
    pt.attempts,
    coalesce((
      select jsonb_agg(jsonb_build_object('path', m.storage_path, 'kind', m.kind) order by m.position)
      from media_assets m where m.post_id = pt.post_id
    ), '[]'::jsonb)
  ;
end;
$$;

revoke all on function public.claim_due_targets(int) from anon, authenticated;
grant execute on function public.claim_due_targets(int) to service_role;
