import { z } from 'zod';
import { query } from '../db.js';

export default async function trending(app) {
  app.get('/v1/trending', async (req, reply) => {
    const Q = z.object({
      window: z.string().default('48h'),
      limit: z.coerce.number().int().min(1).max(50).default(10),
      userId: z.string().uuid().optional()
    });

    const qp = Q.safeParse(req.query);
    if (!qp.success) return reply.code(400).send({ error: 'Bad Request', issues: qp.error.issues });
    const { window, limit, userId } = qp.data;

    // parse "48h" -> hours
    const m = window.match(/^(\d+)\s*h$/i);
    const hours = m ? parseInt(m[1],10) : 48;

    // base rows
    const { rows } = await query(`
      WITH base AS (
        SELECT
          tc.object_type, tc.object_id, tc.creator_id, u.handle AS creator_handle,
          tc.title, tc.created_at, tc.likes_count, tc.comments_count, tc.follows_count,
          tc.score, tc.window_hours
        FROM trending_cache tc
        JOIN users u ON u.id = tc.creator_id
        WHERE tc.window_hours = $1
      ),
      follows AS (
        SELECT followee_id
        FROM follows
        WHERE follower_id = $2::uuid
      )
      SELECT
        b.*,
        CASE WHEN $2::uuid IS NOT NULL AND f.followee_id IS NOT NULL
             THEN ROUND(b.score * 1.10, 8)   -- +10% if user follows the creator
             ELSE b.score
        END AS score
      FROM base b
      LEFT JOIN follows f ON b.creator_id = f.followee_id
      ORDER BY score DESC, created_at DESC
      LIMIT $3
    `, [hours, userId ?? null, limit]);

    return reply.send({ ok: true, windowHours: hours, items: rows });
  });
}
