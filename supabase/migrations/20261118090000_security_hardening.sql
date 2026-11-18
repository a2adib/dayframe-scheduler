-- ── Security hardening ──────────────────────────────────────────────────────
-- 1. Rows that reference other rows must reference the caller's own rows.
--    Without this, a user could attach someone else's channel_id to their
--    own post_target and claim_due_targets (security definer) would publish
--    it with the victim's token.
-- 2. Server-managed columns (plan, channel status/token, subscriptions) are
--    no longer writable from the client.

-- 1a. post_targets: post and channel must belong to the caller.
drop policy if exists "own rows" on post_targets;
create policy "own rows" on post_targets for all
  using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and exists (select 1 from posts p where p.id = post_id and p.user_id = auth.uid())
    and exists (select 1 from channels c where c.id = channel_id and c.user_id = auth.uid())
  );

-- 1b. media_assets: the file must live in the caller's storage folder and
--     the post (if any) must be theirs. publish-due signs these paths with
--     the service key, so an arbitrary path would leak another user's media.
drop policy if exists "own rows" on media_assets;
create policy "own rows" on media_assets for all
  using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and storage_path like auth.uid()::text || '/%'
    and (post_id is null or exists (select 1 from posts p where p.id = post_id and p.user_id = auth.uid()))
  );

-- 1c. engagement_items: channel and post must belong to the caller.
drop policy if exists "own rows" on engagement_items;
create policy "own rows" on engagement_items for all
  using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and exists (select 1 from channels c where c.id = channel_id and c.user_id = auth.uid())
    and (post_id is null or exists (select 1 from posts p where p.id = post_id and p.user_id = auth.uid()))
  );

-- 2a. channels are created and refreshed by Edge Functions (service role).
--     Clients may only pause/unpause and delete.
revoke insert, update on channels from authenticated, anon;
grant update (is_paused) on channels to authenticated;

-- 2b. profiles are created by the auth trigger; plan is server-managed.
revoke insert, update on profiles from authenticated, anon;
grant update (display_name, avatar_url, timezone, theme, updated_at) on profiles to authenticated;

-- 2c. subscriptions are written only by the server.
revoke insert, update, delete on subscriptions from authenticated, anon;

-- 3. Server-side OAuth state. The signed `state` sent to the provider now
--    carries only a random nonce; the user, platform and PKCE verifier live
--    here and are deleted on first use, so a state can't be replayed and the
--    verifier never travels in the authorize URL.
create table if not exists oauth_states (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  platform platform not null,
  code_verifier text,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);
alter table oauth_states enable row level security;
-- No policies: only the service role (Edge Functions) can read or write.
revoke all on oauth_states from authenticated, anon;
create index if not exists oauth_states_expires_idx on oauth_states(expires_at);
