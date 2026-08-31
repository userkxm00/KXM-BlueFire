create extension if not exists pgcrypto;

create table if not exists public.telemetry_events (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  schema_version integer not null default 1,
  kxm_version text not null,
  event_name text not null check (event_name in ('optimize','game_ready','session_end','undo','restore','benchmark','feedback')),
  cpu_vendor text not null default 'Unknown',
  cpu_family text not null default 'Unknown',
  logical_processors smallint not null default 0 check (logical_processors between 0 and 256),
  ram_tier_gb smallint not null default 0 check (ram_tier_gb between 0 and 1024),
  gpu_vendor text not null default 'Unknown',
  gpu_tier text not null default 'unknown',
  storage_class text not null default 'unknown',
  game text not null default '',
  emulator text not null default '',
  profile text not null default '',
  changes jsonb not null default '[]'::jsonb,
  success boolean not null default true,
  reboot_required boolean not null default false,
  restored boolean not null default false,
  result_class text not null default 'neutral' check (result_class in ('positive','neutral','negative')),
  benchmark jsonb,
  source_hash text
);

create table if not exists public.community_insights (
  hardware_key text not null,
  game text not null,
  profile text not null,
  operation_key text not null,
  sample_count integer not null default 0,
  success_count integer not null default 0,
  positive_count integer not null default 0,
  negative_count integer not null default 0,
  rollback_count integer not null default 0,
  updated_at timestamptz not null default now(),
  primary key (hardware_key,game,profile,operation_key)
);

create index if not exists telemetry_created_idx on public.telemetry_events(created_at desc);
create index if not exists telemetry_group_idx on public.telemetry_events(cpu_vendor,gpu_vendor,storage_class,ram_tier_gb,game,profile);
create index if not exists insights_sample_idx on public.community_insights(sample_count desc);

alter table public.telemetry_events enable row level security;
alter table public.community_insights enable row level security;

create or replace function public.is_kxm_admin()
returns boolean language sql stable security definer set search_path = public
as $$
  select coalesce((auth.jwt()->'app_metadata'->>'role') = 'admin', false);
$$;

revoke all on table public.telemetry_events from anon, authenticated;
grANT insert, update, delete on table public.telemetry_events to service_role;

grant select on table public.community_insights to authenticated;

drop policy if exists community_admin_select on public.community_insights;
create policy community_admin_select on public.community_insights
for select to authenticated using (public.is_kxm_admin());

create or replace view public.community_insights_public as
select
  hardware_key,
  game,
  profile,
  sum(sample_count)::int as sample_count,
  case when sum(sample_count)=0 then 0 else sum(success_count)::numeric/sum(sample_count) end as success_rate,
  case when sum(sample_count)=0 then 0 else sum(rollback_count)::numeric/sum(sample_count) end as rollback_rate,
  case when sum(sample_count)<25 then 0 else least(1, greatest(0, (sum(positive_count)-sum(negative_count))::numeric/sum(sample_count))) end as confidence
from public.community_insights
group by hardware_key,game,profile
having sum(sample_count) >= 5;

grant select on public.community_insights_public to authenticated;

create or replace function public.kxm_ingest_event(p_event jsonb)
returns void language plpgsql security definer set search_path = public
as $$
declare
  hw text;
  op text;
  rclass text;
  ok boolean;
  restored_flag boolean;
  g text;
  p text;
  i text;
begin
  if jsonb_typeof(p_event) <> 'object' then raise exception 'invalid payload'; end if;
  if length(coalesce(p_event->>'kxm_version','')) > 32 then raise exception 'invalid version'; end if;
  hw := concat_ws('|', coalesce(p_event#>>'{hardware,cpu_vendor}','Unknown'), coalesce(p_event#>>'{hardware,cpu_family}','Unknown'), coalesce(p_event#>>'{hardware,ram_tier_gb}','0'), coalesce(p_event#>>'{hardware,gpu_vendor}','Unknown'), coalesce(p_event#>>'{hardware,gpu_tier}','unknown'), coalesce(p_event#>>'{hardware,storage_class}','unknown'));
  g := left(coalesce(p_event#>>'{target,game}',''),64);
  p := left(coalesce(p_event#>>'{target,profile}',''),64);
  i := left(coalesce(p_event->>'event','feedback'),32);
  ok := coalesce((p_event#>>'{result,success}')::boolean,true);
  restored_flag := coalesce((p_event#>>'{result,restored}')::boolean,false);
  rclass := case when restored_flag then 'negative' when ok then 'positive' else 'negative' end;

  insert into public.telemetry_events(kxm_version,event_name,cpu_vendor,cpu_family,logical_processors,ram_tier_gb,gpu_vendor,gpu_tier,storage_class,game,emulator,profile,changes,success,reboot_required,restored,result_class,benchmark)
  values(
    left(coalesce(p_event->>'kx_version','unknown'),32),
    case when i in ('optimize','game_ready','session_end','undo','restore','benchmark','feedback') then i else 'feedback' end,
    left(coalesce(p_event#>>'{hardware,cpu_vendor}','Unknown'),32),
    left(coalesce(p_event#>>'{hardware,cpu_family}','Unknown'),64),
    least(256,greatest(0,coalesce((p_event#>>'{hardware,logical_processors}')::int,0))),
    least(1024,greatest(0,coalesce((p_event#>>'{hardware,ram_tier_gb}')::int,0))),
    left(coalesce(p_event#>>'{hardware,gpu_vendor}','Unknown'),32),
    left(coalesce(p_event#>>'{hardware,gpu_tier}','unknown'),32),
    left(coalesce(p_event#>>'{hardware,storage_class}','unknown'),32),
    g,
    left(coalesce(p_event#>>'{target,emulator}',''),64),
    p,
    coalesce(p_event->'changes','[]'::jsonb),
    ok,
    coalesce((p_event#>>'{result,reboot_required}')::boolean,false),
    restored_flag,
    rclass,
    case when jsonb_typeof(p_event#>'{result,benchmark}')='object' then p_event#>'{result,benchmark}' else null end
  );

  for op in select jsonb_array_elements_text(coalesce(p_event->'changes','[]'::jsonb)) loop
    insert into public.community_insights(hardware_key,game,profile,operation_key,sample_count,success_count,positive_count,negative_count,rollback_count)
    values(hw,g,p,op,1,case when ok then 1 else 0 end,case when rclass='positive' then 1 else 0 end,case when rclass='negative' then 1 else 0 end,case when restored_flag then 1 else 0 end)
    on conflict (hardware_key,game,profile,operation_key) do update set
      sample_count=community_insights.sample_count+1,
      success_count=community_insights.success_count+excluded.success_count,
      positive_count=community_insights.positive_count+excluded.positive_count,
      negative_count=community_insights.negative_count+excluded.negative_count,
      rollback_count=community_insights.rollback_count+excluded.rollback_count,
      updated_at=now();
  end loop;
end;
$$;

revoke all on function public.kxm_ingest_event(jsonb) from public, anon, authenticated;
grant execute on function public.kxm_ingest_event(jsonb) to service_role;

create or replace function public.kxm_admin_summary()
returns table(total_samples bigint,total_buckets bigint,positive_rate numeric,rollback_rate numeric)
language sql stable security definer set search_path=public
as $$
select coalesce(sum(sample_count),0),count(*),
       case when coalesce(sum(sample_count),0)=0 then 0 else sum(positive_count)::numeric/sum(sample_count) end,
       case when coalesce(sum(sample_count),0)=0 then 0 else sum(rollback_count)::numeric/sum(sample_count) end
from public.community_insights;
$$;
revoke all on function public.kxm_admin_summary() from public, anon;
grant execute on function public.kxm_admin_summary() to authenticated;
