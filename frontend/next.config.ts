import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Optimize package imports for better tree-shaking
  experimental: {
    optimizePackageImports: ["wagmi", "viem", "@tanstack/react-query"],
  },
};

export default nextConfig;
