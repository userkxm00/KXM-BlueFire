import { NextResponse } from "next/server";
import { cookies } from "next/headers";
import { createServerClient } from "@supabase/ssr";

export async function GET(){
  const cookieStore=await cookies();
  const url=process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key=process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if(!url||!key) return NextResponse.json({error:"Supabase is not configured."},{status:500});
  const supabase=createServerClient(url,key,{cookies:{getAll(){return cookieStore.getAll()},setAll(){}}});
  const {data:{user}}=await supabase.auth.getUser();
  if(!user || user.app_metadata?.role!=="admin") return NextResponse.json({error:"Unauthorized"},{status:401});
  const {data,error}=await supabase.from("community_insights_public").select("hardware_key,game,profile,sample_count,success_rate,rollback_rate,confidence").order("sample_count",{ascending:false}).limit(100);
  if(error) return NextResponse.json({error:error.message},{status:500});
  return NextResponse.json({status:"Ready",insights:data||[]});
}
