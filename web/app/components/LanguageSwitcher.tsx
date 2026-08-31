"use client";

import { useEffect, useState } from "react";

const labels = { en: "English", ar: "العربية", fr: "Français" } as const;
type Lang = keyof typeof labels;

export default function LanguageSwitcher() {
  const [lang, setLang] = useState<Lang>("en");
  useEffect(() => {
    const saved = (localStorage.getItem("kxm-lang") as Lang | null) || "en";
    setLang(saved);
    document.documentElement.lang = saved;
    document.documentElement.dir = saved === "ar" ? "rtl" : "ltr";
  }, []);
  function change(next: Lang) {
    setLang(next);
    localStorage.setItem("kxm-lang", next);
    document.documentElement.lang = next;
    document.documentElement.dir = next === "ar" ? "rtl" : "ltr";
  }
  return (
    <select className="lang-select" value={lang} onChange={(e) => change(e.target.value as Lang)} aria-label="Language">
      {(Object.keys(labels) as Lang[]).map((key) => <option key={key} value={key}>{labels[key]}</option>)}
    </select>
  );
}
