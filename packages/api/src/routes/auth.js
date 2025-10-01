import { z } from 'zod';
import { query } from '../db.js';
import { signJwt } from '../lib/jwt.js';

export default async function authRoutes(app) {
  app.post('/v1/auth/dev-login', async (req, reply) => {
    const Q = z.object({ handle: z.string().min(2).max(32) });
    const p = Q.safeParse(req.body);
    if (!p.success) return reply.code(400).send({ error: 'Bad Request', issues: p.error.issues });

    const { handle } = p.data;
    const r = await query(
      `insert into users(handle, display_name)
       values ($1, initcap($1))
       on conflict (handle) do update set display_name = excluded.display_name
       returning id, handle, display_name`,
      [handle]
    );
    const u = r.rows[0];
    const token = signJwt({ sub: u.id, handle: u.handle });
    return { ok: true, user: u, token };
  });
}
