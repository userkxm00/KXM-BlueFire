import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const cors = {'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'apikey, authorization, content-type','Access-Control-Allow-Methods':'GET, OPTIONS','Content-Type':'application/json'}
function json(data: unknown,status=200){return new Response(JSON.stringify(data),{status,headers:cors})}
Deno.serve(async(req)=>{
  if(req.method==='OPTIONS') return new Response('ok',{headers:cors})
  if(req.method!=='GET') return json({error:'GET required'},405)
  const apiKey=req.headers.get('apikey')
  const publishable=Deno.env.get('KXM_PUBLISHABLE_KEY')
  if(!publishable||apiKey!==publishable) return json({error:'Unauthorized'},401)
  const secret=Deno.env.get('SUPABASE_SECRET_KEY')
  const supabaseUrl=Deno.env.get('SUPABASE_URL')
  if(!secret||!supabaseUrl) return json({error:'Server configuration missing'},500)
  const supabase=createClient(supabaseUrl,secret,{auth:{persistSession:false,autoRefreshToken:false}})
  const limit=Math.min(Math.max(Number(new URL(req.url).searchParams.get('limit')??25),1),100)
  const {data,error}=await supabase.from('community_insights_public').select('hardware_key,game,profile,sample_count,success_rate,rollback_rate,confidence').order('sample_count',{ascending:false}).limit(limit)
  if(error) return json({error:'Query failed'},500)
  return json({schema:1,generated_at:new Date().toISOString(),insights:data??[]})
})
