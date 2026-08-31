import type { Metadata } from "next";
import "./globals.css";
import SiteNav from "./components/SiteNav";

export const metadata: Metadata = {
  title: "KXM BlueFire — Hardware-aware gaming performance",
  description: "KXM BlueFire prepares Windows and BlueStacks for gaming with recovery-first, hardware-aware optimization and community evidence.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return <html lang="en" suppressHydrationWarning><body><SiteNav/>{children}</body></html>;
}
