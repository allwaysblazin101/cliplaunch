import { verifyJwt } from '../lib/jwt.js';
import { query } from '../db.js';

export default async function auth(app) {
  app.addHook('preHandler', async (req, _reply) => {
    const h = req.headers.authorization || '';
    const m = /^Bearer\s+(.+)/i.exec(h);
    if (!m) return;
    const decoded = verifyJwt(m[1]);
    if (!decoded?.sub) return;
    const r = await query('select id, handle, display_name from users where id = $1 limit 1', [decoded.sub]);
    if (r.rowCount) req.user = r.rows[0];
  });
}
