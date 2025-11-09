"use client";

import { AuthProvider } from "react-oidc-context";
import { ReactNode } from "react";
import {
  CognitoConfigProvider,
  useCognitoConfig,
} from "./CognitoConfigContext";
import { Loading } from "@/app/components/Loading";

// Top-level wrapper
export const AuthConfigProvider = ({ children }: { children: ReactNode }) => {
  return (
    <CognitoConfigProvider>
      <InnerAuthProvider>{children}</InnerAuthProvider>
    </CognitoConfigProvider>
  );
};

// Waits for config to load before rendering AuthProvider
const InnerAuthProvider = ({ children }: { children: ReactNode }) => {
  const { config, loading } = useCognitoConfig();

  if (loading || !config) return <Loading message="Configuring Auth..." />;

  return <AuthProvider {...config}>{children}</AuthProvider>;
};
