-- ── Analytics (Phase 6): hourly refresh-metrics cron job ─────────────────────
-- Reads the same two Vault secrets as the publish-due job (see that migration).

select cron.schedule(
  'refresh-metrics',
  '0 * * * *',
  $$
  select net.http_post(
    url := coalesce(
      (select decrypted_secret from vault.decrypted_secrets where name = 'functions_base_url'),
      'http://kong:8000'
    ) || '/functions/v1/refresh-metrics',
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
