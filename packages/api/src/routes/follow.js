import { z } from 'zod';
import { query } from '../db.js';

export default async function follow(app) {
  // Follow (idempotent)
  app.post('/v1/follow', async (req, reply) => {
    const B = z.object({
      follower: z.string().uuid(),
      followee: z.string().uuid(),
    }).safeParse(req.body);
    if (!B.success) return reply.code(400).send({ error: 'Bad Request', issues: B.error.issues });
    const { follower, followee } = B.data;

    // optional: prevent self-follow
    if (follower === followee) return reply.code(400).send({ error: 'Cannot follow yourself' });

    // ensure users exist (cheap guards; remove if you trust callers)
    const u = await query('SELECT id FROM users WHERE id = ANY($1::uuid[])', [[follower, followee]]);
    if (u.rowCount !== 2) return reply.code(404).send({ error: 'Unknown follower or followee' });

    await query(`
      INSERT INTO follows (follower_id, followee_id)
      VALUES ($1,$2)
      ON CONFLICT (follower_id, followee_id) DO NOTHING
    `, [follower, followee]);

    return reply.send({ ok: true });
  });

  // Unfollow (optional)
  app.delete('/v1/follow', async (req, reply) => {
    const Q = z.object({
      follower: z.string().uuid(),
      followee: z.string().uuid(),
    }).safeParse({ ...req.query, ...req.body });
    if (!Q.success) return reply.code(400).send({ error: 'Bad Request', issues: Q.error.issues });

    const { follower, followee } = Q.data;
    await query('DELETE FROM follows WHERE follower_id=$1 AND followee_id=$2', [follower, followee]);
    return reply.send({ ok: true });
  });
}
