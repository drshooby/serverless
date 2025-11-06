const AWS_REGION = process.env.NEXT_PUBLIC_AWS_REGION || "us-east-1";

export const cognitoAuthConfig = {
  authority: `https://cognito-idp.${AWS_REGION}.amazonaws.com/${process.env.NEXT_PUBLIC_COGNITO_USER_POOL_ID}`,
  client_id: process.env.NEXT_PUBLIC_COGNITO_CLIENT_ID!,
  redirect_uri: process.env.NEXT_PUBLIC_COGNITO_REDIRECT_URI!,
  response_type: "code",
  scope: "phone openid email",
  onSigninCallback: () => {
    window.history.replaceState({}, document.title, window.location.pathname);
  },
};

export const cognitoLogoutConfig = {
  domain: `https://${process.env.NEXT_PUBLIC_COGNITO_DOMAIN}.auth.${AWS_REGION}.amazoncognito.com`,
  clientId: process.env.NEXT_PUBLIC_COGNITO_CLIENT_ID!,
  redirect_uri: process.env.NEXT_PUBLIC_COGNITO_REDIRECT_URI!,
  response_type: "code",
  scope: "email openid phone",
};
