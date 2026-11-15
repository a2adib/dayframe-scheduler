-- ==============================================================================
-- 24/7 Scheduling Engine Setup: Supabase Vault Configuration
-- ==============================================================================
-- Run this once in your Supabase Cloud Dashboard -> SQL Editor
-- (https://supabase.com/dashboard/project/gllzmbwndzvaoonyerov/sql/new)

select vault.create_secret('https://gllzmbwndzvaoonyerov.supabase.co', 'functions_base_url');
select vault.create_secret('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdsbHptYnduZHp2YW9vbnllcm92Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5NDY2NjMyNSwiZXhwIjoyMTEwMjQyMzI1fQ.b-vfb5oez6sLe2zsM-uJmpyJ67-Bt_6BnLUVpdYNRSw', 'service_role_key');

-- Verification query: Verify both secrets are stored in Vault
select id, name, created_at from vault.decrypted_secrets where name in ('functions_base_url', 'service_role_key');
