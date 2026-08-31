create table if not exists public.kxm_telemetry_events (
  id uuid primary key default gen_random_uuid(),
  schema_version integer not null check (schema_version = 1),
  kxm_version text not null check (char_length(kxm_version) between 1 and 32),
  event_name text not null check (event_name in ('optimize','game_ready','session_end','session_undo','restore','benchmark')),
  received_at timestamptz not null default now(),
  event_day date not null default current_date,
  cpu_vendor text,
  cpu_family text,
  logical_processors smallint,
  ram_tier_gb smallint,
  gpu_vendor text,
  gpu_tier text,
  storage_class text,
  windows_build_tier text,
  emulator text,
  emulator_version text,
  game text,
  profile text,
  success boolean not null default true,
  reboot_required boolean not null default false,
  restored boolean not null default false,
  change_ids jsonb not null default '[]'::jsonb,
  benchmark jsonb,
  client_day_key text,
  constraint kxm_telemetry_change_ids_array check (jsonb_typeof(change_ids) = 'array')
);

create index if not exists kxm_telemetry_event_day_idx on public.kxm_telemetry_events(event_day);
create index if not exists kxm_telemetry_profile_idx on public.kxm_telemetry_events(profile, game, storage_class, ram_tier_gb);
create index if not exists kxm_telemetry_event_idx on public.kxm_telemetry_events(event_name);

alter table public.kxm_telemetry_events enable row level security;
revoke all on table public.kxm_telemetry_events from anon, authenticated;

create table if not exists public.kxm_telemetry_rate_limits (
  bucket_key text primary key,
  bucket_day date not null default current_date,
  request_count integer not null default 0,
  updated_at timestamptz not null default now()
);
alter table public.kxm_telemetry_rate_limits enable row level security;
revoke all on table public.kxm_telemetry_rate_limits from anon, authenticated;

create or replace view public.kxm_community_insights as
select
  game,
  profile,
  gpu_vendor,
  storage_class,
  ram_tier_gb,
  count(*) as samples,
  round(avg(case when success then 1 else 0 end) * 100.0, 1) as success_rate,
  round(avg(case when restored then 1 else 0 end) * 100.0, 1) as restore_rate,
  round(avg(case when reboot_required then 1 else 0 end) * 100.0, 1) as reboot_rate
from public.kxm_telemetry_events
group by game, profile, gpu_vendor, storage_class, ram_tier_gb;

revoke all on public.kxm_community_insights from anon, authenticated;
