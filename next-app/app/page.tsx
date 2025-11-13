"use client";

import { useAuth } from "react-oidc-context";
import { useEffect, useCallback } from "react";
import { useSiteConfig } from "@/app/auth/SiteConfigContext";
import { Loading } from "@/app/components/Loading";
import { HomePage } from "@/app/components/HomePage";

export default function Home() {
  const auth = useAuth();
  const { config, loading } = useSiteConfig();

  // Redirect to login if not authenticated
  const redirectToLogin = useCallback(() => {
    if (!auth.isAuthenticated && !auth.isLoading && !auth.activeNavigator) {
      auth.signinRedirect();
    }
  }, [auth]);

  useEffect(() => {
    const justLoggedOut = sessionStorage.getItem("logging_out");
    if (justLoggedOut) {
      sessionStorage.removeItem("logging_out");
    } else {
      redirectToLogin();
    }

    // Clean up OAuth params from URL after successful auth
    if (
      auth.isAuthenticated &&
      (window.location.search.includes("code=") ||
        window.location.search.includes("state="))
    ) {
      window.history.replaceState({}, document.title, window.location.pathname);
    }
  }, [redirectToLogin]);

  // Logout handler using dynamic config
  const signOut = async () => {
    if (!config) return;

    sessionStorage.setItem("logging_out", "true");
    await auth.removeUser();

    const logoutUrl = new URL(`${config.domain}/logout`);
    logoutUrl.searchParams.set("response_type", config.response_type);
    logoutUrl.searchParams.set("client_id", config.client_id);
    logoutUrl.searchParams.set("redirect_uri", config.redirect_uri);
    logoutUrl.searchParams.set("scope", config.scopes);

    window.location.href = logoutUrl.toString();
  };

  if (loading || auth.isLoading) return <Loading />;
  if (auth.error) return <div>Oops... {auth.error.message}</div>;
  if (!auth.isAuthenticated) return <Loading message="Signing you out" />;

  const username =
    auth.user?.profile["nickname"] ||
    (auth.user?.profile["cognito:username"] as string) ||
    "Agent";
  const email = auth.user?.profile.email as string;

  const bucket = config?.upload_bucket || "";
  if (bucket === "") {
    throw new Error("No upload bucket found!");
  }

  return (
    <HomePage
      username={username}
      email={email}
      bucketURL={config?.upload_bucket as string}
      onSignOut={signOut}
    />
  );
}
