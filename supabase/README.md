# KXM Community Backend

This directory contains the Supabase backend for privacy-first KXM community telemetry.

## Components

- `migrations/20260830230000_kxm_community_telemetry.sql`
  - telemetry event table
  - RLS enabled
  - direct client table access revoked
  - aggregated community-insights view
- `migrations/20260830231000_kxm_telemetry_rate_limit.sql`
  - server-side rate-limit RPC
- `functions/kxm-telemetry/index.ts`
  - validates and sanitizes incoming events
  - accepts the public publishable key as the API key
  - writes through the server-only secret key
- `functions/kxm-community-insights/index.ts`
  - exposes only aggregated groups with at least 5 samples
- `config.toml`
  - public functions use application-level `apikey` validation

## Required Edge Function secrets

Set these only in Supabase Edge Function secrets:

- `SUPABASE_SECRET_KEY` = your Supabase `sb_secret_...` key
- `KXM_PUBLISHABLE_KEY` = your Supabase `sb_publishable_...` key
- `KXM_TELEMETRY_RATE_SALT` = a new long random server-only salt

Never put `SUPABASE_SECRET_KEY` in KXM client files. Supabase documents secret keys as backend-only and notes that they bypass RLS. Publishable keys are intended for public clients when RLS/least-privilege access is used.

## Deployment

Use the Supabase CLI from the project root:

```text
supabase db push
supabase secrets set SUPABASE_SECRET_KEY=... KXM_PUBLISHABLE_KEY=... KXM_TELEMETRY_RATE_SALT=...
supabase functions deploy kxm-telemetry --no-verify-jwt
supabase functions deploy kxm-community-insights --no-verify-jwt
```

The client endpoint is:

`https://<project-ref>.supabase.co/functions/v1/kxm-telemetry`

The insights endpoint is:

`https://<project-ref>.supabase.co/functions/v1/kxm-community-insights`

KXM Community Telemetry remains opt-in. No secret key is shipped with the desktop client.
