import { z } from 'zod';
import { query } from '../db.js';

export default async function follows(app) {
  // POST /v1/follow  — idempotent follow
  app.post('/v1/follow', async (req, reply) => {
    const Q = z.object({
      follower: z.string().uuid(),
      followee: z.string().uuid(),
    });
    const p = Q.safeParse(req.body);
    if (!p.success) return reply.code(400).send({ error: 'Bad Request', issues: p.error.issues });

    const { follower, followee } = p.data;
    // prevent self-follow just in case
    if (follower === followee) return reply.code(400).send({ error: 'Cannot follow self' });

    // idempotent upsert
    await query(
      `INSERT INTO follows (follower_id, followee_id)
       VALUES ($1, $2)
       ON CONFLICT (follower_id, followee_id) DO NOTHING`,
      [follower, followee]
    );

    return reply.send({ ok: true });
  });

  // (optional) GET who someone follows
  app.get('/v1/follows', async (req, reply) => {
    const Q = z.object({
      userId: z.string().uuid(),
      limit: z.coerce.number().int().min(1).max(200).default(50),
    });
    const p = Q.safeParse(req.query);
    if (!p.success) return reply.code(400).send({ error: 'Bad Request', issues: p.error.issues });

    const { userId, limit } = p.data;
    const { rows } = await query(
      `SELECT f.followee_id AS user_id, u.handle, u.display_name, f.created_at
       FROM follows f
       JOIN users u ON u.id = f.followee_id
       WHERE f.follower_id = $1
       ORDER BY f.created_at DESC
       LIMIT $2`,
      [userId, limit]
    );
    return reply.send({ ok: true, items: rows });
  });
}
