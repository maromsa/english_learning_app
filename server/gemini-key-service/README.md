# Gemini Key Service

Minimal Node.js (Express) service that stores the Gemini API key in a secure environment variable and hands it out only to trusted clients. Deploy it to the platform of your choice (Cloud Run, Vercel, Fly.io, etc.).

## Why

Keeping the Gemini key inside the mobile app or source control is risky. This service lets you keep the key on the server and issue it at runtime only to authenticated clients.

## How it works

1. Client calls `GET /v1/gemini-token` with header `x-service-key: <shared secret>`.
2. Service checks the shared secret.
3. On success it returns JSON:

   ```json
   {
     "token": "<gemini api key>",
     "issuedAt": 1710000000,
     "expiresAt": 1710003600
   }
   ```

4. Client caches the token until `expiresAt`.

## Setup

```bash
cd server/gemini-key-service
cp .env.example .env
```

Edit `.env` and set:

- `SERVICE_API_KEY`: random string shared with trusted apps.
- `GEMINI_API_KEY`: your actual Gemini key.
- `TOKEN_TTL_SECONDS`: optional expiry window (default 3600 seconds).

Install dependencies and run locally:

```bash
npm install
npm run dev
```

Deploy the service to your hosting provider. Be sure to configure HTTPS, set the environment variables securely, and restrict network access/ingress as needed.

## Request example

```bash
curl -H "x-service-key: $SERVICE_API_KEY" https://<your-service>/v1/gemini-token
```

If the header is missing or incorrect you will get `401 Unauthorized`.

## Hardening ideas

- Issue per-device access tokens instead of a shared key.
- Add rate limiting, logging, and alerting.
- Rotate `SERVICE_API_KEY` and `GEMINI_API_KEY` regularly.
- Optionally, proxy Gemini requests directly through the service instead of returning the raw key.
