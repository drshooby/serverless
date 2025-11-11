# Radiant

This project is for my Cloud Computing final with the following requirements:

## Project Overview

This project is a full-fledged AI Single Page Application (SPA) built with serverless architecture and cloud infrastructure. It demonstrates best practices in modern cloud deployment, security, and AI integration.

## Requirements

- **Static Page**: Served via cloud storage (S3) as the frontend SPA.
- **API Backend**: AWS API Gateway routing to Lambda functions to process REST endpoints (no GraphQL used).
- **Authentication**: Implemented with Amazon Cognito, supporting username/password login plus one OAuth provider.
- **Database**: Cloud-hosted RDBMS for persistent storage (no DynamoDB).
- **DNS & CDN**: Custom domain with Cloudflare for DNS, CDN caching, and SSL; HTTPS enforced.
- **Security**: Protection against DDoS attacks and ReCaptcha integration via Cloudflare.
- **AI Integration**: Connects to an external ML API (approved for use in this project).
- **Constraints**: No AWS Amplify, Google Firebase, or other automatic SaaS/PaaS deployment tools.

## Local Dev

- The following variables are **required** for local dev. Please view `next-app/app/auth/auth.config.ts` for formatting:

```bash
NEXT_PUBLIC_COGNITO_CLIENT_ID=
NEXT_PUBLIC_COGNITO_ENDPOINT=
NEXT_PUBLIC_COGNITO_DOMAIN=
NEXT_PUBLIC_COGNITO_REDIRECT_URI=
```

- Addtionally, confirm/update any `CORS` policies in `infra/aws/api_gateway.tf`

## Google Auth

Cognito utilizes **Google OAUTH 2.0** for the additional sign-in requirement.

### Setup Steps

1. Create a Google Cloud Platform account (if you don’t have one).
2. Go to APIs & Services → Credentials.
3. Click Create Credentials → OAuth client ID and choose Web application.
4. Configure the Authorised JavaScript origins:

```
https://<your-cognito-domain>.auth.<region>.amazoncognito.com
```

5. Configure the Authorized redirect URIs:

```
https://<your-cognito-domain>.auth.<region>.amazoncognito.com/oauth2/idpresponse
```

> **NOTE**: The main uri for the two previous steps can be found in the `cognito_pool_domain` output of Terraform.

6. Note down the generated `Client ID` and `Client Secret`.

7. In this repository, navigate to `infra/aws` and create a `terraform.tfvars` file containing:

```
google_auth_client_id     = "YOUR CLIENT ID"
google_auth_client_secret = "YOUR CLIENT SECRET"
```

Once done, Google sign-in will be enabled in the Cognito UI.

## Project Status & Next Steps

### Completed

- **Static Page**: SPA served via S3.
- **Authentication**: Username/password + Google OAUTH 2.0 login via Amazon Cognito fully implemented.
- **DNS & CDN**: Custom domain set up with Cloudflare, SSL/HTTPS enforced.
- **DDOS Protection**: Just turn on `under attack` mode.

### In Progress / To Do

- [ ] **Database**: Connect and configure cloud-hosted RDBMS for persistent storage.
- [ ] **Backend API**: Implement Lambda functions behind API Gateway to handle REST endpoints.
- [ ] **AI Integration**: Connect SPA/backend to external ML API for approved project functionality.
- [ ] **Security Enhancements**:
  - [ ] Explore Cloudflare Turnstile for bot protection.

### Notes

- Run `aws secretsmanager delete-secret --secret-id cognito-config --force-delete-without-recovery` between `terraform destroy` and `terraform apply` because AWS doesn't want you accidentally deleting your secrets (although in this case it's intentional).

