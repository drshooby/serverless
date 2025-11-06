# Serverless (new name in progress)

This project is for my Cloud Computing final with the following requirements:

## Project Overview
This project is a full-fledged AI Single Page Application (SPA) built with serverless architecture and cloud infrastructure. It demonstrates best practices in modern cloud deployment, security, and AI integration.

## Requirements Implemented
- **Static Page**: Served via cloud storage (S3) as the frontend SPA.  
- **API Backend**: AWS API Gateway routing to Lambda functions to process REST endpoints (no GraphQL used).  
- **Authentication**: Implemented with Amazon Cognito, supporting username/password login plus one OAuth provider.  
- **Database**: Cloud-hosted RDBMS for persistent storage (no DynamoDB).  
- **DNS & CDN**: Custom domain with Cloudflare for DNS, CDN caching, and SSL; HTTPS enforced.  
- **Security**: Protection against DDoS attacks and ReCaptcha integration via Cloudflare.  
- **AI Integration**: Connects to an external ML API (approved for use in this project).  
- **Constraints**: No AWS Amplify, Google Firebase, or other automatic SaaS/PaaS deployment tools.
