"use client";

import Link from "next/link";
import { GithubLogo } from "@phosphor-icons/react";
import LanguageSwitcher from "./LanguageSwitcher";

export default function SiteNav(){
  return <header className="nav"><div className="shell nav-inner">
    <Link href="/" className="brand">KXM <span>//</span> BLUEFIRE</Link>
    <nav className="nav-links" aria-label="Main navigation">
      <Link href="/">Home</Link><Link href="/profiles">Profiles</Link><Link href="/community">Community</Link><Link href="/docs">Docs</Link><Link href="/download">Download</Link>
    </nav>
    <div style={{display:"flex",alignItems:"center",gap:10}}><LanguageSwitcher/><a className="btn" href="https://github.com/userkxm00/KXM-BlueFire" target="_blank" rel="noreferrer"><GithubLogo size={18}/> GitHub</a></div>
  </div></header>
}
