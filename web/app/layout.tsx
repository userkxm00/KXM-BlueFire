import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "KXM BlueFire — Gaming Performance Platform",
  description: "Hardware-aware gaming optimization for Windows, BlueStacks and Free Fire.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return <html lang="en"><body>{children}</body></html>;
}
