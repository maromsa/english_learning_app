import {onRequest} from 'firebase-functions/v2/https';
import {defineInt, defineSecret, defineString} from 'firebase-functions/params';

const geminiApiKey = defineSecret('GEMINI_API_KEY');
const geminiServiceKey = defineSecret('GEMINI_SERVICE_KEY');
const tokenTtlSecondsParam = defineInt('GEMINI_TOKEN_TTL', 3600);
const allowedOriginsParam = defineString('GEMINI_ALLOWED_ORIGINS', '');

const parseAllowedOrigins = () => {
  const raw = allowedOriginsParam.value().trim();
  if (!raw) {
    return [];
  }

  return raw
    .split(',')
    .map((origin) => origin.trim())
    .filter((origin) => origin.length > 0);
};

const resolveAllowOrigin = (origin) => {
  if (!origin) {
    return undefined;
  }

  const allowedOrigins = parseAllowedOrigins();
  if (allowedOrigins.length === 0) {
    return undefined;
  }

  if (allowedOrigins.includes('*')) {
    return '*';
  }

  return allowedOrigins.includes(origin) ? origin : undefined;
};

const getTokenTtlSeconds = () => {
  const value = tokenTtlSecondsParam.value();
  if (Number.isFinite(value) && value >= 60) {
    return value;
  }

  return 3600;
};

export const geminiToken = onRequest(
  {
    region: 'us-central1',
    secrets: [geminiApiKey, geminiServiceKey],
    cors: false,
  },
  async (req, res) => {
    if (req.method === 'OPTIONS') {
      const allowOrigin = resolveAllowOrigin(req.get('Origin'));
      if (allowOrigin) {
        res.set('Access-Control-Allow-Origin', allowOrigin);
      }
      res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
      res.set('Access-Control-Allow-Headers', 'x-service-key');
      res.set('Access-Control-Max-Age', '3600');
      return res.status(204).send('');
    }

    if (req.method !== 'GET') {
      res.set('Allow', 'GET, OPTIONS');
      return res.status(405).json({error: 'method_not_allowed'});
    }

    const serviceKey = geminiServiceKey.value();
    if (!serviceKey) {
      console.error('GEMINI_SERVICE_KEY secret is not configured.');
      return res.status(500).json({error: 'service_misconfigured'});
    }

    const providedKey = req.get('x-service-key') ?? '';
    if (providedKey !== serviceKey) {
      return res.status(401).json({error: 'unauthorized'});
    }

    const apiKey = geminiApiKey.value();
    if (!apiKey) {
      console.error('GEMINI_API_KEY secret is not configured.');
      return res.status(500).json({error: 'service_misconfigured'});
    }

    const allowOrigin = resolveAllowOrigin(req.get('Origin'));
    if (allowOrigin) {
      res.set('Access-Control-Allow-Origin', allowOrigin);
    } else {
      res.set('Vary', 'Origin');
    }

    const issuedAt = Math.floor(Date.now() / 1000);
    const ttlSeconds = getTokenTtlSeconds();
    const expiresAt = issuedAt + ttlSeconds;

    res.set('Cache-Control', 'private, max-age=0, no-store');
    return res.json({
      token: apiKey,
      issuedAt,
      expiresAt,
    });
  },
);
