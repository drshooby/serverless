import type { Metadata } from "next";
import { Jost } from "next/font/google";

import { AuthConfigProvider } from "@/app/auth/AuthConfigProvider";

import "./globals.css";

export const metadata: Metadata = {
  title: "Radiant",
  description: "David's Cloud Computing final project.",
};

// If loading a variable font, you don't need to specify the font weight
const jost = Jost({ subsets: ["latin"] });

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className={jost.className}>
        <AuthConfigProvider>{children}</AuthConfigProvider>
      </body>
    </html>
  );
}
