"use client";

import { useAuth } from "react-oidc-context";
import { useEffect, useCallback } from "react";
import { useCognitoConfig } from "@/app/auth/CognitoConfigContext";
import { Loading } from "@/app/components/Loading";

export default function Home() {
  const auth = useAuth();
  const { config, loading } = useCognitoConfig();

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

  if (loading || auth.isLoading) return <Loading message="Logging you in..." />;
  if (auth.error) return <div>Oops... {auth.error.message}</div>;
  if (!auth.isAuthenticated) return <Loading message="Signing you out..." />;

  return (
    <div>
      <h1>Hi, {auth.user?.profile.email}</h1>
      <button onClick={signOut}>Sign out</button>

      <hr />

      <div style={{ marginTop: "1rem", fontSize: "0.9rem" }}>
        <h3>Session Info (Debug)</h3>
        <pre>
          ID Token Exp:{" "}
          {new Date((auth.user?.profile.exp ?? 0) * 1000).toLocaleString()}
          {"\n"}
          Access Token Expires In:{" "}
          {Math.round((auth.user?.expires_in ?? 0) / 60)} min{"\n"}
          Token Type: {auth.user?.token_type ?? "N/A"}
          {"\n\n"}
          ID Token:{"\n"}
          {auth.user?.id_token ?? "N/A"}
          {"\n\n"}
          Access Token:{"\n"}
          {auth.user?.access_token ?? "N/A"}
        </pre>
      </div>
    </div>
  );
}
