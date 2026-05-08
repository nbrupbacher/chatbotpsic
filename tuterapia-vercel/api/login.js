// /api/login.js
// Vercel Serverless Function — Node runtime.
// Recibe { user, pass } y devuelve un token firmado con HMAC si las credenciales son válidas.

import crypto from 'crypto';

// Token expira a los 7 días. Subilo o bajalo a gusto.
const TOKEN_TTL_MS = 7 * 24 * 60 * 60 * 1000;

function signToken(payload, secret) {
  const data = Buffer.from(JSON.stringify(payload)).toString('base64url');
  const sig = crypto.createHmac('sha256', secret).update(data).digest('base64url');
  return `${data}.${sig}`;
}

// Parsea AUTH_CREDENTIALS="user1:pass1,user2:pass2" → [{user, pass}, ...]
function parseCredentials(envValue) {
  if (!envValue) return [];
  return envValue.split(',').map(pair => {
    const [user, ...passParts] = pair.split(':');
    return { user: user.trim(), pass: passParts.join(':').trim() };
  }).filter(c => c.user && c.pass);
}

// Comparación constant-time para evitar timing attacks
function safeEqual(a, b) {
  if (a.length !== b.length) return false;
  return crypto.timingSafeEqual(Buffer.from(a), Buffer.from(b));
}

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const secret = process.env.AUTH_SECRET;
  const credsEnv = process.env.AUTH_CREDENTIALS;

  if (!secret || !credsEnv) {
    console.error('Faltan env vars: AUTH_SECRET y/o AUTH_CREDENTIALS');
    return res.status(500).json({ error: 'Servidor mal configurado' });
  }

  const { user, pass } = req.body || {};
  if (typeof user !== 'string' || typeof pass !== 'string') {
    return res.status(400).json({ error: 'Faltan credenciales' });
  }

  const credentials = parseCredentials(credsEnv);
  const match = credentials.find(c =>
    safeEqual(c.user, user) && safeEqual(c.pass, pass)
  );

  if (!match) {
    // Pequeño delay para no facilitar enumeración por timing
    await new Promise(r => setTimeout(r, 300));
    return res.status(401).json({ error: 'Usuario o contraseña incorrectos' });
  }

  const token = signToken(
    { user: match.user, exp: Date.now() + TOKEN_TTL_MS },
    secret
  );

  return res.status(200).json({ token, user: match.user });
}
