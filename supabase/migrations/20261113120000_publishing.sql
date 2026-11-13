-- ── Publishing engine (Phase 5): claim RPC, token vault helpers, pg_cron ─────

create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;

-- Claims due targets atomically: FOR UPDATE SKIP LOCKED so concurrent runs
-- never double-publish; flips claimed rows to `publishing` and returns
-- everything publish-due needs (post body, platform, media paths).
create or replace function public.claim_due_targets(p_limit int default 10)
returns table (
  target_id uuid,
  post_id uuid,
  user_id uuid,
  channel_id uuid,
  platform platform,
  body text,
  body_override text,
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

-- Edge Functions store platform tokens in Vault through this helper.
create or replace function public.store_token_secret(p_secret text)
returns uuid
language sql
security definer
set search_path = extensions, vault, public
as $$
  select vault.create_secret(p_secret);
$$;

revoke all on function public.store_token_secret(text) from anon, authenticated;
grant execute on function public.store_token_secret(text) to service_role;

-- publish-due reads tokens through this helper (no direct vault grants needed).
create or replace function public.read_token_secret(p_secret_id uuid)
returns text
language sql
security definer
set search_path = extensions, vault, public
as $$
  select decrypted_secret from vault.decrypted_secrets where id = p_secret_id;
$$;

revoke all on function public.read_token_secret(uuid) from anon, authenticated;
grant execute on function public.read_token_secret(uuid) to service_role;

-- ── Cron: invoke publish-due every minute ────────────────────────────────────
-- Needs two Vault secrets (created once per environment, never committed):
--   service_role_key  → Bearer token for the function
--   functions_base_url→ e.g. http://kong:8000 (local) or https://<ref>.supabase.co
select cron.schedule(
  'publish-due',
  '* * * * *',
  $$
  select net.http_post(
    url := coalesce(
      (select decrypted_secret from vault.decrypted_secrets where name = 'functions_base_url'),
      'http://kong:8000'
    ) || '/functions/v1/publish-due',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || coalesce(
        (select decrypted_secret from vault.decrypted_secrets where name = 'service_role_key'),
        ''
      )
    ),
    body := '{}'::jsonb
  );
  $$
);
