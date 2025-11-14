export interface SiteSettings {
  authority: string;
  client_id: string;
  redirect_uri: string;
  domain: string;
  response_type: string;
  scopes: string;
  gateway_url: string;
  upload_bucket: string;
  ffmpeg_success: string;
}

const SCOPES = "email openid profile";
const RESPONSE_TYPE = "code";

let cachedConfig: SiteSettings | null = null;

// Normalize either local env or Lambda fetch result into SiteSettings
function normalizeConfig(data: Record<string, string>): SiteSettings {
  return {
    authority: data.NEXT_PUBLIC_COGNITO_ENDPOINT || data.COGNITO_ENDPOINT!,
    client_id: data.NEXT_PUBLIC_COGNITO_CLIENT_ID || data.COGNITO_CLIENT_ID!,
    redirect_uri:
      data.NEXT_PUBLIC_COGNITO_REDIRECT_URI || data.COGNITO_REDIRECT_URI!,
    domain: data.NEXT_PUBLIC_COGNITO_DOMAIN || data.COGNITO_DOMAIN!,
    response_type: RESPONSE_TYPE,
    scopes: SCOPES,
    gateway_url: data.GATEWAY_URL || "",
    upload_bucket: data.UPLOAD_BUCKET || "",
    ffmpeg_success: data.FFMPEG_STATUS || ""
  };
}

export async function getAuthVars(): Promise<SiteSettings> {
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
  } else {
    // Production: fetch from Lambda
    const GATEWAY_URL = "GATEWAY_PLACEHOLDER_URL"
    if (!GATEWAY_URL.startsWith("https")) { 
      throw new Error("GATEWAY_URL was not replaced during build - check your sed script");
    }
    const res = await fetch(`${GATEWAY_URL}/cognito`);
    if (!res.ok) throw new Error("Failed to fetch Cognito config from Lambda");
    data = await res.json();
    data.GATEWAY_URL = GATEWAY_URL
    console.log(data.FFMPEG_STATUS)
  }

  cachedConfig = normalizeConfig(data);
  return cachedConfig;
}
