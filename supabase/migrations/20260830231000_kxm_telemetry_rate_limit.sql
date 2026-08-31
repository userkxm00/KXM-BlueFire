create or replace function public.kxm_consume_rate_limit(
  p_bucket_key text,
  p_bucket_day date,
  p_limit integer default 120
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  new_count integer;
begin
  if p_bucket_key is null or char_length(p_bucket_key) = 0 then
    return true;
  end if;

  insert into public.kxm_telemetry_rate_limits(bucket_key, bucket_day, request_count, updated_at)
  values (p_bucket_key, p_bucket_day, 1, now())
  on conflict (bucket_key) do update
    set request_count = case
          when kxm_telemetry_rate_limits.bucket_day = excluded.bucket_day
            then kxm_telemetry_rate_limits.request_count + 1
          else 1
        end,
        bucket_day = excluded.bucket_day,
        updated_at = now()
  returning request_count into new_count;

  return new_count <= greatest(1, least(p_limit, 1000));
end;
$$;

revoke all on function public.kxm_consume_rate_limit(text, date, integer) from public, anon, authenticated;
