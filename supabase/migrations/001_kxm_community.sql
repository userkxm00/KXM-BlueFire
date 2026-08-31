create extension if not exists pgcrypto;

create table if not exists public.kxm_telemetry_events (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  schema_version integer not null default 1,
  kxm_version text not null,
  event_name text not null check (event_name in ('optimize','game_ready','session_end','session_undo','restore','benchmark','feedback')),
  cpu_vendor text default 'Unknown',
  cpu_family text default 'Unknown',
  logical_processors smallint check (logical_processors between 0 and 256),
  ram_tier_gb smallint check (ram_tier_gb between 0 and 1024),
  gpu_vendor text default 'Unknown',
  gpu_tier text default 'unknown',
  storage_class text default 'unknown',
  windows_build_tier text default 'unknown',
  emulator text default '',
  emulator_version text default '',
  game text default 'Unknown',
  profile text default 'General',
  success boolean not null default false,
  reboot_required boolean not null default false,
  restored boolean not null default false,
  change_ids jsonb not null default '[]'::jsonb,
  benchmark jsonb,
  result_class text not null default 'neutral' check (result_class in ('positive','neutral','negative'))
);

create table if not exists public.community_insights (
  hardware_key text not null,
  game text not null,
  profile text not null,
  operation_key text not null,
  sample_count integer not null default 0 check(sample_count >= 0),
  success_count integer not null default 0 check(success_count >= 0),
  positive_count integer not null default 0 check(positive_count >= 0),
  negative_count integer not null default 0 check(negative_count >= 0),
  rollback_count integer not null default 0 check(rollback_count >= 0),
  updated_at timestamptz not null default now(),
  primary key (hardware_key,game,profile,operation_key)
);

create table if not exists public.kxm_rate_limits (
  bucket_key text not null,
  bucket_day date not null,
  request_count integer not null default 0,
  updated_at timestamptz not null default now(),
  primary key(bucket_key,bucket_day)
);

create index if not exists kxm_events_created_idx on public.kxm_telemetry_events(created_at desc);
create index if not exists kxm_events_group_idx on public.kxm_telemetry_events(cpu_vendor,gpu_vendor,ram_tier_gb,storage_class,game,profile);
create index if not exists kxm_insights_sample_idx on public.community_insights(sample_count desc);

alter table public.kxm_telemetry_events enable row level security;
alter table public.community_insights enable row level security;
alter table public.kxm_rate_limits enable row level security;

create or replace function public.kxm_is_admin()
returns boolean
language sql stable security definer set search_path=public
as $$ select coalesce((auth.jwt()->'app_metadata'->>'role')='admin',false); $$;

revoke all on public.kxm_telemetry_events from anon, authenticated;
revoke all on public.kxm_rate_limits from anon, authenticated;
grant select on public.community_insights to authenticated;

drop policy if exists kxm_admin_insights on public.community_insights;
create policy kxm_admin_insights on public.community_insights
for select to authenticated using (public.kxm_is_admin());

create or replace view public.community_insights_public
with (security_invoker=true)
as
select
  hardware_key,
  game,
  profile,
  sum(sample_count)::int as sample_count,
  case when sum(sample_count)=0 then 0 else round(sum(success_count)::numeric/sum(sample_count),4) end as success_rate,
  case when sum(sample_count)=0 then 0 else round(sum(rollback_count)::numeric/sum(sample_count),4) end as rollback_rate,
  case when sum(sample_count)<25 then 0 else least(1,numeric_greatest_zero((sum(positive_count)-sum(negative_count))::numeric/sum(sample_count))) end as confidence
from public.community_insights
group by hardware_key,game,profile
having sum(sample_count)>=5;

-- Helper used by the view; avoids leaking negative confidence.
create or replace function public.numeric_greatest_zero(v numeric)
returns numeric language sql immutable as $$ select greatest(0,v); $$;

revoke all on function public.numeric_greatest_zero(numeric) from public;
grant execute on function public.numeric_greatest_zero(numeric) to authenticated;
grant select on public.community_insights_public to authenticated;

create or replace function public.kxm_consume_rate_limit(p_bucket_key text,p_bucket_day date,p_limit integer default 120)
returns boolean
language plpgsql security definer set search_path=public
as $$
declare n integer;
begin
  if p_limit < 1 or p_limit > 5000 then return false; end if;
  insert into public.kxm_rate_limits(bucket_key,bucket_day,request_count)
  values(left(p_bucket_key,128),p_bucket_day,1)
  on conflict(bucket_key,bucket_day) do update set request_count=public.kxm_rate_limits.request_count+1,updated_at=now()
  returning request_count into n;
  return n <= p_limit;
end;
$$;
revoke all on function public.kxm_consume_rate_limit(text,date,integer) from public,anon,authenticated;
grant execute on function public.kxm_consume_rate_limit(text,date,integer) to service_role;

create or replace function public.kxm_ingest_trigger()
returns trigger language plpgsql security definer set search_path=public
as $$
declare hw text; op text; rclass text;
begin
  hw:=concat_ws('|',coalesce(new.cpu_vendor,'Unknown'),coalesce(new.cpu_family,'Unknown'),coalesce(new.ram_tier_gb::text,'0'),coalesce(new.gpu_vendor,'Unknown'),coalesce(new.gpu_tier,'unknown'),coalesce(new.storage_class,'unknown'));
  rclass:=case when new.restored then 'negative' when new.success then 'positive' else 'negative' end;
  for op in select jsonb_array_elements_text(coalesce(new.change_ids,'[]'::jsonb)) loop
    insert into public.community_insights(hardware_key,game,profile,operation_key,sample_count,success_count,positive_count,negative_count,rollback_count)
    values(hw,coalesce(new.game,'Unknown'),coalesce(new.profile,'General'),op,1,case when new.success then 1 else 0 end,case when rclass='positive' then 1 else 0 end,case when rclass='negative' then 1 else 0 end,case when new.restored then 1 else 0 end)
    on conflict(hardware_key,game,profile,operation_key) do update set
      sample_count=community_insights.sample_count+1,
      success_count=community_insights.success_count+excluded.success_count,
      positive_count=community_insights.positive_count+excluded.positive_count,
      negative_count=community_insights.negative_count+excluded.negative_count,
      rollback_count=community_insights.rollback_count+excluded.rollback_count,
      updated_at=now();
  end loop;
  return new;
end;
$$;

drop trigger if exists kxm_ingest_after_insert on public.kxm_telemetry_events;
create trigger kxm_ingest_after_insert after insert on public.kxm_telemetry_events
for each row execute function public.kxm_ingest_trigger();

revoke all on function public.kxm_ingest_trigger() from public,anon,authenticated;
grant execute on function public.kxm_ingest_trigger() to service_role;
