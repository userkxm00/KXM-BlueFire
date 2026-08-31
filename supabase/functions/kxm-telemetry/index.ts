import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'apikey, authorization, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Content-Type': 'application/json',
}

const MAX_BODY = 32_000
const MAX_CHANGES = 64
const ALLOWED_EVENTS = new Set(['optimize', 'game_ready', 'session_end', 'session_undo', 'restore', 'benchmark'])
const ALLOWED_PROFILES = new Set(['Free Fire', 'Free Fire MAX', 'BlueStacks', 'General', 'Competitive', 'Experimental'])
const ALLOWED_GAMES = new Set(['Free Fire', 'Free Fire MAX', 'Unknown'])

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: cors })
}

function cleanText(value: unknown, max = 64): string | null {
  if (typeof value !== 'string') return null
  const s = value.trim()
  return s.length > 0 && s.length <= max ? s : null
}

function cleanBool(value: unknown): boolean {
  return value === true
}

function cleanInt(value: unknown, min: number, max: number): number | null {
  const n = Number(value)
  if (!Number.isInteger(n) || n < min || n > max) return null
  return n
}

function cleanBenchmark(value: unknown) {
  if (!value || typeof value !== 'object') return null
  const v = value as Record<string, unknown>
  const out: Record<string, number> = {}
  for (const k of ['avg_fps', 'one_percent_low', 'zero_point_one_percent_low', 'avg_frame_time_ms', 'jitter_ms', 'ping_ms']) {
    const n = Number(v[k])
    if (Number.isFinite(n) && n >= 0 && n <= 100000) out[k] = Number(n.toFixed(3))
  }
  return Object.keys(out).length ? out : null
}

function bucketKey(req: Request) {
  // Server-side rate limiting key. It is never persisted as a readable IP.
  // Hashing requires a server-only salt stored in Edge Function secrets.
  return req.headers.get('cf-connecting-ip') ?? req.headers.get('x-forwarded-for') ?? 'unknown'
}

async function hmac(value: string, secret: string) {
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'])
  const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(value))
  return Array.from(new Uint8Array(sig)).map((b) => b.toString(16).padStart(2, '0')).join('')
}

async function rateLimit(supabase: ReturnType<typeof createClient>, req: Request) {
  const secret = Deno.env.get('KXM_TELEMETRY_RATE_SALT') ?? ''
  const raw = bucketKey(req)
  const key = await hmac(raw, secret || 'kxm-rate-limit-default')
  const day = new Date().toISOString().slice(0, 10)
  const { data } = await supabase.rpc('kxm_consume_rate_limit', { p_bucket_key: key, p_bucket_day: day, p_limit: 120 })
  return data !== false
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  if (req.method !== 'POST') return json({ error: 'POST required' }, 405)

  const apiKey = req.headers.get('apikey')
  const publishable = Deno.env.get('KXM_PUBLISHABLE_KEY')
  if (!publishable || apiKey !== publishable) return json({ error: 'Unauthorized' }, 401)

  const secret = Deno.env.get('SUPABASE_SECRET_KEY')
  const supabaseUrl = Deno.env.get('SUPABASE_URL')
  if (!secret || !supabaseUrl) return json({ error: 'Server configuration missing' }, 500)

  let bodyText = ''
  try {
    bodyText = await req.text()
  } catch {
    return json({ error: 'Invalid body' }, 400)
  }
  if (bodyText.length > MAX_BODY) return json({ error: 'Payload too large' }, 413)

  let body: Record<string, unknown>
  try {
    body = JSON.parse(bodyText)
  } catch {
    return json({ error: 'Invalid JSON' }, 400)
  }

  const eventName = cleanText(body.event, 32)
  if (!eventName || !ALLOWED_EVENTS.has(eventName)) return json({ error: 'Invalid event' }, 422)

  const target = (body.target && typeof body.target === 'object') ? body.target as Record<string, unknown> : {}
  const hardware = (body.hardware && typeof body.hardware === 'object') ? body.hardware as Record<string, unknown> : {}
  const result = (body.result && typeof body.result === 'object') ? body.result as Record<string, unknown> : {}

  const profile = cleanText(target.profile, 64)
  const game = cleanText(target.game, 64)
  if (profile && !ALLOWED_PROFILES.has(profile)) return json({ error: 'Invalid profile' }, 422)
  if (game && !ALLOWED_GAMES.has(game)) return json({ error: 'Invalid game' }, 422)

  const changes = Array.isArray(body.changes) ? body.changes.slice(0, MAX_CHANGES).map((x) => cleanText(x, 64)).filter(Boolean) : []
  const clientVersion = cleanText(body.kx_version, 32)
  const schemaVersion = cleanInt(body.schema, 1, 1)
  if (schemaVersion !== 1 || !clientVersion) return json({ error: 'Unsupported schema' }, 422)

  const supabase = createClient(supabaseUrl, secret, { auth: { persistSession: false, autoRefreshToken: false } })
  if (!(await rateLimit(supabase, req))) return json({ error: 'Rate limit exceeded' }, 429)

  const row = {
    schema_version: 1,
    kxm_version: clientVersion,
    event_name: eventName,
    cpu_vendor: cleanText(hardware.cpu_vendor, 24),
    cpu_family: cleanText(hardware.cpu_family, 48),
    logical_processors: cleanInt(hardware.logical_processors, 0, 256),
    ram_tier_gb: cleanInt(hardware.ram_tier_gb, 0, 1024),
    gpu_vendor: cleanText(hardware.gpu_vendor, 24),
    gpu_tier: cleanText(hardware.gpu_tier, 32),
    storage_class: cleanText(hardware.storage_class, 32),
    windows_build_tier: cleanText(hardware.windows_build_tier, 32),
    emulator: cleanText(target.emulator, 32),
    emulator_version: cleanText(target.emulator_version, 48),
    game: game ?? 'Unknown',
    profile: profile ?? 'General',
    success: cleanBool(result.success),
    reboot_required: cleanBool(result.reboot_required),
    restored: cleanBool(result.restored),
    change_ids: changes,
    benchmark: cleanBenchmark(result.benchmark),
  }

  const { error } = await supabase.from('kxm_telemetry_events').insert(row)
  if (error) return json({ error: 'Ingest failed' }, 500)

  return json({ ok: true })
})
