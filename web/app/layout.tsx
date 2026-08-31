import type { Metadata } from "next";
import "./globals.css";
import SiteNav from "./components/SiteNav";

export const metadata: Metadata = {
  title: "KXM BlueFire — Measured Windows Gaming Performance",
  description: "Hardware-aware Windows gaming optimization for BlueStacks and Free Fire, built around recovery, measurement and community evidence.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" dir="ltr">
      <body>
        <SiteNav />
        {children}
      </body>
    </html>
  );
}
