import 'dotenv/config';

import cors from 'cors';
import express from 'express';
import helmet from 'helmet';
import morgan from 'morgan';

const {
  PORT = 8080,
  SERVICE_API_KEY,
  GEMINI_API_KEY,
  TOKEN_TTL_SECONDS = '3600',
} = process.env;

if (!SERVICE_API_KEY) {
  throw new Error('SERVICE_API_KEY must be set in the environment.');
}

if (!GEMINI_API_KEY) {
  throw new Error('GEMINI_API_KEY must be set in the environment.');
}

const tokenTtlSeconds = Number.parseInt(TOKEN_TTL_SECONDS, 10) || 3600;

const app = express();
app.disable('x-powered-by');
app.use(helmet());
app.use(cors({ origin: false }));
app.use(morgan('combined'));

app.get('/healthz', (_req, res) => {
  res.json({ status: 'ok', uptime: process.uptime() });
});

app.get('/v1/gemini-token', (req, res) => {
  const providedKey = req.header('x-service-key') ?? '';

  if (providedKey !== SERVICE_API_KEY) {
    return res.status(401).json({ error: 'unauthorized' });
  }

  const issuedAt = Math.floor(Date.now() / 1000);
  const expiresAt = issuedAt + tokenTtlSeconds;

  return res.json({
    token: GEMINI_API_KEY,
    issuedAt,
    expiresAt,
  });
});

app.listen(Number(PORT), () => {
  // eslint-disable-next-line no-console
  console.log(`Gemini key service listening on port ${PORT}`);
});
