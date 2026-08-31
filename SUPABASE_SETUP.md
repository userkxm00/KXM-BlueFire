# KXM Community Backend Setup

## 1. Rotate the exposed secret key
A secret key must never be stored in KXM, GitHub or browser code. Rotate any secret that has been shared publicly.

## 2. Apply the database migration
Open Supabase SQL Editor and run:

`supabase/migrations/001_kxm_community.sql`

It creates telemetry storage, aggregated insights, rate limiting, RLS and the aggregation trigger.

## 3. Configure Edge Function secrets
Set these secrets in Supabase Edge Functions:

- `SUPABASE_URL`
- `SUPABASE_SECRET_KEY` (or the current Supabase server-only secret variable supported by your project)
- `KXM_PUBLISHABLE_KEY`
- `KXM_TELEMETRY_RATE_SALT`

Never commit the secret value.

## 4. Deploy functions
Deploy both:

- `supabase/functions/kxm-telemetry`
- `supabase/functions/kxm-community-insights`

The desktop client should send only to the telemetry function. The function validates schema, limits payload size, rate-limits requests and writes with the server secret.

## 5. Configure KXM admin
Create an administrator in Supabase Auth and set the user's `app_metadata.role` to `admin`. The web dashboard checks this claim before returning community insights.

## 6. Configure Vercel
Use these environment variables on the server:

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`

The public key may be used by browser code. Do not place the server secret in any `NEXT_PUBLIC_*` variable.

## 7. Data flow

`KXM client -> Supabase Edge Function -> kxm_telemetry_events -> community_insights -> Admin Dashboard`

Community sharing remains opt-in. The aggregate view is intended to expose only coarse hardware classes and outcome statistics.
