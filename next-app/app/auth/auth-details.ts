export interface CognitoSettings {
  authority: string;
  client_id: string;
  redirect_uri: string;
  domain: string;
  response_type: string;
  scopes: string;
  gateway_url: string
}

const SCOPES = "email openid";
const RESPONSE_TYPE = "code";

let cachedConfig: CognitoSettings | null = null;

// Normalize either local env or Lambda fetch result into CognitoSettings
function normalizeConfig(data: Record<string, string>): CognitoSettings {
  return {
    authority: data.NEXT_PUBLIC_COGNITO_ENDPOINT || data.COGNITO_ENDPOINT!,
    client_id: data.NEXT_PUBLIC_COGNITO_CLIENT_ID || data.COGNITO_CLIENT_ID!,
    redirect_uri:
      data.NEXT_PUBLIC_COGNITO_REDIRECT_URI || data.COGNITO_REDIRECT_URI!,
    domain: data.NEXT_PUBLIC_COGNITO_DOMAIN || data.COGNITO_DOMAIN!,
    response_type: RESPONSE_TYPE,
    scopes: SCOPES,
    gateway_url: data.GATEWAY_URL || ""
  };
}

export async function getAuthVars(): Promise<CognitoSettings> {
  if (cachedConfig) return cachedConfig;

  let data: Record<string, string>;

  const NEXT_PUBLIC_COGNITO_CLIENT_ID = process.env.NEXT_PUBLIC_COGNITO_CLIENT_ID || ""
  const NEXT_PUBLIC_COGNITO_ENDPOINT = process.env.NEXT_PUBLIC_COGNITO_ENDPOINT || ""
  const NEXT_PUBLIC_COGNITO_DOMAIN = process.env.NEXT_PUBLIC_COGNITO_DOMAIN || ""
  const NEXT_PUBLIC_COGNITO_REDIRECT_URI = process.env.NEXT_PUBLIC_COGNITO_REDIRECT_URI || ""

  const hasLocalEnv = 
    NEXT_PUBLIC_COGNITO_CLIENT_ID &&
    NEXT_PUBLIC_COGNITO_ENDPOINT &&
    NEXT_PUBLIC_COGNITO_DOMAIN &&
    NEXT_PUBLIC_COGNITO_REDIRECT_URI;

  if (hasLocalEnv) {
    // Local dev
    data = {
      NEXT_PUBLIC_COGNITO_ENDPOINT,
      NEXT_PUBLIC_COGNITO_CLIENT_ID,
      NEXT_PUBLIC_COGNITO_REDIRECT_URI,
      NEXT_PUBLIC_COGNITO_DOMAIN,
    };
    console.log("Using local NEXT_PUBLIC env for Cognito config:", data);
  } else {
    // Production: fetch from Lambda
    const GATEWAY_URL = "https://jx7siawh2a.execute-api.us-east-1.amazonaws.com/prod" // PLACEHOLDER_URL for sed
    // if (GATEWAY_URL === "PLACEHOLDER_URL") {
    //   throw new Error("GATEWAY_URL was not replaced during build - check your sed script");
    // }
    const res = await fetch(`${GATEWAY_URL}/api/cognito`);
    if (!res.ok) throw new Error("Failed to fetch Cognito config from Lambda");
    data = await res.json();
    data.GATEWAY_URL = GATEWAY_URL
    console.log("Fetched Cognito config from Lambda:", data);
  }

  cachedConfig = normalizeConfig(data);
  console.log("Normalized Cognito config:", cachedConfig);

  return cachedConfig;
}
