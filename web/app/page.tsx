"use client";

import { motion } from "motion/react";
import { ArrowUpRight, DownloadSimple, GithubLogo, Gauge, ShieldCheck, Database, Cpu, ChartLineUp } from "@phosphor-icons/react";

const stats = [
  ["01", "DETECT", "Hardware-aware profiles instead of blind tweaks."],
  ["02", "PROTECT", "Baseline, sessions and reversible changes."],
  ["03", "MEASURE", "Benchmark outcomes before claiming a win."],
  ["04", "LEARN", "Opt-in community evidence improves recommendations."],
];

export default function Home() {
  return (
    <main>
      <nav className="shell" style={{display:"flex",justifyContent:"space-between",alignItems:"center"}}>
        <a href="#top" style={{fontWeight:800,letterSpacing:"-.03em",fontSize:20}}>KXM <span style={{color:"var(--accent)"}}>//</span> BLUEFIRE</a>
        <div style={{display:"flex",gap:10}}>
          <a className="btn" href="https://github.com/userkxm00/KXM-BlueFire"><GithubLogo size={18}/> GitHub</a>
          <a className="btn btn-primary" href="#download"><DownloadSimple size={18}/> Download</a>
        </div>
      </nav>

      <section id="top" className="grid-bg" style={{minHeight:"82vh",display:"flex",alignItems:"center"}}>
        <div className="shell" style={{width:"100%",paddingTop:80,paddingBottom:100}}>
          <div className="mono" style={{color:"var(--accent)",fontSize:13,letterSpacing:".14em"}}>WINDOWS // BLUESTACKS // FREE FIRE</div>
          <h1 className="hero-title">Performance should be <span style={{color:"var(--accent)"}}>measured.</span></h1>
          <p className="muted" style={{fontSize:20,maxWidth:720,lineHeight:1.6,marginTop:28}}>
            KXM BlueFire is a hardware-aware Windows gaming performance platform built around a simple rule: detect the machine, protect the original state, apply only what fits, measure the result, and make rollback easy.
          </p>
          <div style={{display:"flex",gap:12,marginTop:34,flexWrap:"wrap"}}>
            <a className="btn btn-primary" href="#download">Get KXM <ArrowUpRight size={18}/></a>
            <a className="btn" href="#how">How it works</a>
          </div>
          <div style={{marginTop:70,maxWidth:920}} className="card">
            <div style={{padding:26,display:"grid",gridTemplateColumns:"repeat(4,1fr)",gap:1,background:"var(--line)"}}>
              {stats.map(([n,t,d])=>(
                <div key={n} style={{background:"var(--panel)",padding:20,minHeight:150}}>
                  <div className="mono" style={{color:"var(--accent)",fontSize:12}}>{n}</div>
                  <div style={{fontWeight:800,fontSize:20,marginTop:14}}>{t}</div>
                  <div className="muted" style={{fontSize:13,lineHeight:1.5,marginTop:8}}>{d}</div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </section>

      <section id="how" className="shell" style={{paddingTop:100,paddingBottom:100}}>
        <div style={{maxWidth:760}}>
          <div className="mono" style={{color:"var(--accent)",fontSize:12}}>SYSTEM MODEL</div>
          <h2 style={{fontSize:"clamp(2.2rem,5vw,4.5rem)",letterSpacing:"-.05em",lineHeight:.98,margin:"16px 0"}}>A gaming optimizer with a memory.</h2>
          <p className="muted" style={{fontSize:18,lineHeight:1.7}}>Every persistent change is treated as state. Sessions can be ended, previous settings can be restored, and community data stays opt-in and coarse.</p>
        </div>
        <div style={{display:"grid",gridTemplateColumns:"repeat(3,1fr)",gap:18,marginTop:48}}>
          {[
            [Cpu,"Hardware Intelligence","CPU, RAM, GPU, storage, virtualization and driver context shape the recommendation."],
            [ShieldCheck,"Recovery First","Baseline snapshots live outside the app folder; session changes are reversible."],
            [ChartLineUp,"Evidence Loop","Benchmark and community outcomes are used to rank recommendations instead of guessing."],
          ].map(([Icon,title,body])=>{
            const I=Icon as any;
            return <motion.article whileHover={{y:-5}} className="card" key={title as string} style={{padding:26}}>
              <I size={30} color="var(--accent)" weight="duotone"/>
              <h3 style={{fontSize:22,margin:"24px 0 10px"}}>{title as string}</h3>
              <p className="muted" style={{lineHeight:1.65}}>{body as string}</p>
            </motion.article>
          })}
        </div>
      </section>

      <section id="download" className="grid-bg" style={{borderTop:"1px solid var(--line)",borderBottom:"1px solid var(--line)"}}>
        <div className="shell" style={{paddingTop:100,paddingBottom:100,display:"grid",gridTemplateColumns:"1.2fr .8fr",gap:30,alignItems:"center"}}>
          <div>
            <div className="mono" style={{color:"var(--accent)",fontSize:12}}>KXM BLUEFIRE v25</div>
            <h2 style={{fontSize:"clamp(2.5rem,5vw,5.2rem)",letterSpacing:"-.05em",lineHeight:.95,margin:"16px 0"}}>Ready when you are.</h2>
            <p className="muted" style={{fontSize:18,lineHeight:1.6,maxWidth:650}}>Free Fire / BlueStacks focused profiles, with safety gates, recovery and multilingual UI. Results vary by hardware and workload; KXM never promises a fixed FPS number.</p>
            <div style={{display:"flex",gap:12,marginTop:28,flexWrap:"wrap"}}>
              <a className="btn btn-primary" href="https://github.com/userkxm00/KXM-BlueFire/releases">View releases <ArrowUpRight size={18}/></a>
              <a className="btn" href="https://github.com/userkxm00/KXM-BlueFire">Source code <GithubLogo size={18}/></a>
            </div>
          </div>
          <div className="card" style={{padding:28}}>
            <div className="mono" style={{fontSize:12,color:"var(--accent)"}}>PROFILE / FREE FIRE</div>
            <div style={{display:"grid",gridTemplateColumns:"1fr 1fr",gap:14,marginTop:22}}>
              {[[Gauge,"CPU","4 cores"],[Database,"RAM","4 GB"],[Gauge,"POWER","High Performance"],[Gauge,"FPS","120 target / 240 ceiling"]].map(([Icon,label,value])=>{const I=Icon as any;return <div key={label as string} style={{padding:16,border:"1px solid var(--line)",borderRadius:16}}><I size={20} color="var(--accent)"/><div className="mono" style={{fontSize:11,color:"var(--muted)",marginTop:12}}>{label as string}</div><div style={{fontWeight:700,marginTop:4}}>{value as string}</div></div>})}
            </div>
          </div>
        </div>
      </section>

      <footer className="shell" style={{paddingTop:30,paddingBottom:40,display:"flex",justifyContent:"space-between",gap:20,flexWrap:"wrap"}}>
        <span className="muted">KXM // BLUEFIRE — open source gaming performance tooling.</span>
        <span className="mono muted">Detect → Protect → Recommend → Measure → Learn → Restore</span>
      </footer>
    </main>
  );
}
