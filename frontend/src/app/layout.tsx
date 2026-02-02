import type { Metadata } from "next";
import { Inter, JetBrains_Mono } from "next/font/google";
import "./globals.css";
import { Providers } from "./providers";

// Inter - clean, simple, readable
const inter = Inter({
  subsets: ["latin"],
  weight: ["400", "500", "600", "700"],
  variable: "--font-inter",
  display: "swap",
});

// JetBrains Mono for numbers
const jetbrainsMono = JetBrains_Mono({
  subsets: ["latin"],
  weight: ["400", "600", "700"],
  variable: "--font-mono",
  display: "swap",
});

const BASE_URL = "https://YOUR_DOMAIN"; // TODO: Update after deployment

export const metadata: Metadata = {
  title: "$LOTTERY - King Game",
  description: "Compete to be the Lottery King and earn $LOTTERY tokens",
  openGraph: {
    title: "$LOTTERY - King Game",
    description: "Compete to be the Lottery King and earn $LOTTERY tokens",
    images: [`${BASE_URL}/og-image.png`],
  },
  other: {
    "fc:frame": "vNext",
    "fc:frame:image": `${BASE_URL}/og-image.png`,
    "fc:frame:button:1": "Play $LOTTERY",
    "fc:frame:button:1:action": "launch_frame",
    "fc:frame:button:1:target": BASE_URL,
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className={`${inter.variable} ${jetbrainsMono.variable}`}>
      <body className="antialiased min-h-screen">
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
