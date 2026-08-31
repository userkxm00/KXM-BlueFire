"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { GithubLogo } from "@phosphor-icons/react";
import LanguageSwitcher from "./LanguageSwitcher";

const links=[['/profiles','Profiles'],['/community','Community'],['/docs','Docs'],['/download','Download'],['/faq','FAQ']];

export default function SiteNav(){
  const pathname=usePathname();
  if(pathname==="/") return null;
  return <header className="nav"><div className="shell nav-inner">
    <Link href="/" className="brand">KXM <span>//</span> BLUEFIRE</Link>
    <nav className="nav-links" aria-label="Main navigation"><Link href="/">Home</Link>{links.map(([href,label])=><Link href={href} key={href}>{label}</Link>)}</nav>
    <div style={{display:"flex",alignItems:"center",gap:10}}><LanguageSwitcher/><a className="btn" href="https://github.com/userkxm00/KXM-BlueFire" target="_blank" rel="noreferrer"><GithubLogo size={18}/> GitHub</a></div>
  </div></header>
}
