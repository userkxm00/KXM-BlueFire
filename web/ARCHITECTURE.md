# KXM BlueFire Web Architecture

## Product surfaces

### Public site
Marketing, product explanation, download, documentation, profiles, privacy, changelog, community statistics.

### Private admin
Authenticated owner-only dashboard for community analytics, profile performance, anomalies, recommendation candidates, approvals and release publishing.

## Data boundary

The browser may use only the Supabase URL and publishable key when client-side data access is required. Secret/service-role credentials are server-only and belong in Vercel/Supabase environment secrets.

KXM desktop telemetry should flow through an authenticated/validated server-side endpoint or Supabase Edge Function. Raw telemetry should never be exposed through public queries.

## Evidence loop

1. KXM sends opt-in, privacy-minimized outcome events.
2. Edge Function validates schema, payload size and rate limits.
3. PostgreSQL stores normalized events.
4. SQL views/functions aggregate by hardware class, game, profile and operation.
5. Admin dashboard surfaces recommendation candidates.
6. Human approval promotes a candidate to a versioned KXM rule/profile.
7. New KXM releases consume the approved rule set.

No automatic rule is allowed to change system tweaks merely because one metric moved. Recommendations require minimum sample sizes, rollback/negative-result thresholds and an explicit approval state.

## UI design principles

This project takes design methodology from Taste Skill v2 and UI UX Pro Max: infer the product/audience before choosing a visual direction; use a coherent design system; avoid generic AI-template patterns; enforce accessibility, responsive text, reduced motion and strong pre-flight checks. Taste Skill explicitly emphasizes brief inference and anti-default discipline, while UI UX Pro Max emphasizes design-system generation, reasoning rules, accessibility and responsive UX.

The KXM site is deliberately original: it does not copy their source code or proprietary visual assets.
