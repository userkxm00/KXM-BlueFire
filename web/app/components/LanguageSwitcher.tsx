"use client";

import { useEffect, useState } from "react";
import { usePathname, useRouter } from "next/navigation";

const labels = { en: "English", ar: "العربية", fr: "Français" } as const;
type Lang = keyof typeof labels;

function localePath(lang: Lang, path: string){
  const clean=path.startsWith('/ar')?path.slice(3)||'/':path.startsWith('/fr')?path.slice(3)||'/':path;
  if(lang==='en') return clean;
  return `/${lang}${clean==='/'?'':clean}`;
}

export default function LanguageSwitcher(){
  const router=useRouter(); const pathname=usePathname();
  const initial: Lang = pathname.startsWith('/ar')?'ar':pathname.startsWith('/fr')?'fr':'en';
  const [lang,setLang]=useState<Lang>(initial);
  useEffect(()=>{setLang(initial);document.documentElement.lang=initial;document.documentElement.dir=initial==='ar'?'rtl':'ltr';localStorage.setItem('kxm-lang',initial)},[pathname]);
  function change(next: Lang){setLang(next);localStorage.setItem('kxm-lang',next);document.documentElement.lang=next;document.documentElement.dir=next==='ar'?'rtl':'ltr';router.push(localePath(next,pathname));}
  return <select className="lang-select" value={lang} onChange={e=>change(e.target.value as Lang)} aria-label="Language">{(Object.keys(labels) as Lang[]).map(k=><option key={k} value={k}>{labels[k]}</option>)}</select>;
}
