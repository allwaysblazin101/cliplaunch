import { z } from 'zod';
import { query } from '../db.js';

export default async function feed(app) {
  app.get('/v1/feed', async (req, reply) => {
    const Q = z.object({
      userId: z.string().uuid().optional(),
      handle: z.string().min(1).optional(),
      limit: z.coerce.number().int().min(1).max(100).default(25)
    });

    const p = Q.safeParse(req.query);
    if (!p.success) return reply.code(400).send({ error: 'Bad Request', issues: p.error.issues });

    let { userId, handle, limit } = p.data;

    // resolve viewer by handle if needed
    if (!userId && handle) {
      const r = await query('SELECT id FROM users WHERE handle=$1 LIMIT 1', [handle]);
      if (!r.rowCount) return reply.code(404).send({ error: 'Unknown handle' });
      userId = r.rows[0].id;
    }

    if (!userId) return reply.code(400).send({ error: 'Missing user' });

    // who the viewer follows
    const f = await query('SELECT followee_id FROM follows WHERE follower_id=$1', [userId]);
    if (!f.rowCount) return { ok: true, items: [] };

    const followeeIds = f.rows.map(r => r.followee_id);

    // activities by followees (actor = user_id who traded)
    const { rows } = await query(
      `
      SELECT a.id,
             a.verb,
             a.object_type,
             a.object_id,
             a.created_at,
             a.actor,
             (a.meta->>'mint')  AS mint,
             (a.meta->>'payer') AS payer,
             u.handle           AS actor_handle,
             t.symbol           AS token_symbol
      FROM activities a
      LEFT JOIN users  u ON u.id = a.actor
      LEFT JOIN tokens t ON t.mint = (a.meta->>'mint')
      WHERE a.actor = ANY($1::uuid[])
      ORDER BY a.created_at DESC
      LIMIT $2
      `,
      [followeeIds, limit]
    );

    return { ok: true, items: rows };
  });
}
