import { z } from 'zod';
import { query } from '../db.js';

export default async function videoLikes(app) {
  // Like a video (idempotent)
  app.post('/v1/videos/:id/like', async (req, reply) => {
    const Q = z.object({ id: z.string().uuid() });
    const B = z.object({ userId: z.string().uuid() });

    const qp = Q.safeParse(req.params);
    if (!qp.success) return reply.code(400).send({ error: 'Bad Request', issues: qp.error.issues });

    const bp = B.safeParse(req.body);
    if (!bp.success) return reply.code(400).send({ error: 'Bad Request', issues: bp.error.issues });

    const { id } = qp.data;
    const { userId } = bp.data;

    const v = await query('SELECT id FROM videos WHERE id=$1 LIMIT 1', [id]);
    if (v.rowCount === 0) return reply.code(404).send({ error: 'Unknown video' });

    await query(`
      INSERT INTO video_likes (video_id, user_id)
      VALUES ($1, $2)
      ON CONFLICT (video_id, user_id) DO NOTHING
    `, [id, userId]);

    return reply.send({ ok: true });
  });

  // Unlike (optional convenience)
  app.delete('/v1/videos/:id/like', async (req, reply) => {
    const Q = z.object({
      id: z.string().uuid(),
      userId: z.string().uuid()
    });
    const qp = Q.safeParse({ ...req.params, ...req.query });
    if (!qp.success) return reply.code(400).send({ error: 'Bad Request', issues: qp.error.issues });

    const { id, userId } = qp.data;
    await query('DELETE FROM video_likes WHERE video_id=$1 AND user_id=$2', [id, userId]);
    return reply.send({ ok: true });
  });
}
