"use client";

import {
  createContext,
  useContext,
  useState,
  useEffect,
  ReactNode,
} from "react";
import { SiteSettings, getAuthVars } from "./auth-details";

interface SiteConfigContextValue {
  config: SiteSettings | null;
  loading: boolean;
}

const SiteConfigContext = createContext<SiteConfigContextValue>({
  config: null,
  loading: true,
});

export const SiteConfigProvider = ({ children }: { children: ReactNode }) => {
  const [config, setConfig] = useState<SiteSettings | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    getAuthVars()
      .then((cfg) => {
        console.log("Cognito config loaded.");
        setConfig(cfg);
      })
      .finally(() => setLoading(false));
  }, []);

  return (
    <SiteConfigContext.Provider value={{ config, loading }}>
      {children}
    </SiteConfigContext.Provider>
  );
};

// Hook to consume config
export const useSiteConfig = () => useContext(SiteConfigContext);
