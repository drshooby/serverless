"use client";

import { AuthProvider } from "react-oidc-context";
import { ReactNode } from "react";
import { SiteConfigProvider, useSiteConfig } from "./SiteConfigContext";
import { Loading } from "@/app/components/Loading";

// Top-level wrapper
export const AuthConfigProvider = ({ children }: { children: ReactNode }) => {
  return (
    <SiteConfigProvider>
      <InnerAuthProvider>{children}</InnerAuthProvider>
    </SiteConfigProvider>
  );
};

// Waits for config to load before rendering AuthProvider
const InnerAuthProvider = ({ children }: { children: ReactNode }) => {
  const { config, loading } = useSiteConfig();

  if (loading || !config) return <Loading />;

  return <AuthProvider {...config}>{children}</AuthProvider>;
};
