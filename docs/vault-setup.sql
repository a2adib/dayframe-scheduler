-- ==============================================================================
-- 24/7 Scheduling Engine Setup: Supabase Vault Configuration
-- ==============================================================================
-- Run this once in your Supabase Cloud Dashboard -> SQL Editor
-- (https://supabase.com/dashboard/project/gllzmbwndzvaoonyerov/sql/new)

select vault.create_secret('https://gllzmbwndzvaoonyerov.supabase.co', 'functions_base_url');
-- Paste your service_role key from Dashboard -> Project Settings -> API. Never commit it.
select vault.create_secret('<YOUR_SERVICE_ROLE_KEY>', 'service_role_key');

-- Verification query: Verify both secrets are stored in Vault
select id, name, created_at from vault.decrypted_secrets where name in ('functions_base_url', 'service_role_key');
