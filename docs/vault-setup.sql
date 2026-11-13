-- ==============================================================================
-- 24/7 Scheduling Engine Setup: Supabase Vault Configuration
-- ==============================================================================
-- Run this once in your Supabase Cloud Dashboard -> SQL Editor.
-- Replace <YOUR_PROJECT_REF> with your actual project reference (e.g. abcdefghijkl)
-- and <YOUR_SERVICE_ROLE_KEY> with your service_role key (from Project Settings -> API).

select vault.create_secret('https://<YOUR_PROJECT_REF>.supabase.co', 'functions_base_url');
select vault.create_secret('<YOUR_SERVICE_ROLE_KEY>', 'service_role_key');

-- Verification query: Verify both secrets are stored in Vault
select id, name, created_at from vault.decrypted_secrets where name in ('functions_base_url', 'service_role_key');
