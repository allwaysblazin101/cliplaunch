import jwt from 'jsonwebtoken';

const SECRET = process.env.APP_SECRET || 'dev-secret-change-me';

export function signJwt(payload, opts = {}) {
  return jwt.sign(payload, SECRET, { expiresIn: '30d', ...opts });
}

export function verifyJwt(token) {
  try { return jwt.verify(token, SECRET); }
  catch { return null; }
}
