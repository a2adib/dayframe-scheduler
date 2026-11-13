#!/usr/bin/env bash
set -e

# Dayframe Supabase Cloud Deployment Script
# Deploys migrations, edge functions, and sets cloud secrets for 24/7 background scheduling.
#
# Usage:
#   ./supabase/deploy.sh <PROJECT_REF> <SERVICE_ROLE_KEY>

PROJECT_REF="$1"
SERVICE_ROLE_KEY="$2"

if [ -z "$PROJECT_REF" ] || [ -z "$SERVICE_ROLE_KEY" ]; then
  echo "Error: Missing arguments."
  echo "Usage: $0 <PROJECT_REF> <SERVICE_ROLE_KEY>"
  echo "You can find your Project Reference and Service Role Key in your Supabase Dashboard -> Project Settings -> API."
  exit 1
fi

echo "==> Linking Supabase Cloud Project: $PROJECT_REF..."
supabase link --project-ref "$PROJECT_REF"

echo "==> Pushing Database Migrations to Cloud..."
supabase db push

echo "==> Deploying Edge Functions..."
supabase functions deploy oauth-start
supabase functions deploy oauth-callback --no-verify-jwt
supabase functions deploy publish-due --no-verify-jwt
supabase functions deploy refresh-metrics --no-verify-jwt

echo "==> Setting Base Cloud Secrets..."
supabase secrets set \
  FUNCTIONS_BASE_URL="https://${PROJECT_REF}.supabase.co" \
  SUPABASE_SERVICE_ROLE_KEY="${SERVICE_ROLE_KEY}"

echo "=========================================================="
echo "✅ Supabase Cloud Backend Deployed Successfully!"
echo "Next step: Run the SQL in docs/vault-setup.sql in your Supabase SQL Editor"
echo "to initialize the 24/7 pg_cron scheduler."
echo "=========================================================="
