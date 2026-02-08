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

const BASE_URL = "https://frontend-yolodolos-projects.vercel.app";

export const metadata: Metadata = {
  title: "$LOTTERY - King Game",
  description: "Compete to be the Lottery King and earn $LOTTERY tokens",
  openGraph: {
    title: "$LOTTERY - King Game",
    description: "Compete to be the Lottery King and earn $LOTTERY tokens",
    images: [`${BASE_URL}/og-image.png`],
  },
  other: {
    "fc:frame": JSON.stringify({
      version: "1",
      imageUrl: `${BASE_URL}/og-image.png`,
      button: {
        title: "Play $LOTTERY",
        action: {
          type: "launch_frame",
          name: "$LOTTERY",
          url: BASE_URL,
          splashImageUrl: `${BASE_URL}/splash.png`,
          splashBackgroundColor: "#1a1a1a",
        },
      },
    }),
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
