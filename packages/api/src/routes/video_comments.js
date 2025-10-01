import { z } from 'zod';
import { query } from '../db.js';

export default async function videoComments(app) {
  // Create a comment
  app.post('/v1/videos/:id/comment', async (req, reply) => {
    const Q = z.object({ id: z.string().uuid() });
    const B = z.object({
      userId: z.string().uuid(),
      body: z.string().min(1).max(2000)
    });

    const qp = Q.safeParse(req.params);
    if (!qp.success) return reply.code(400).send({ error: 'Bad Request', issues: qp.error.issues });

    const bp = B.safeParse(req.body);
    if (!bp.success) return reply.code(400).send({ error: 'Bad Request', issues: bp.error.issues });

    const { id } = qp.data;
    const { userId, body } = bp.data;

    const v = await query('SELECT id FROM videos WHERE id=$1 LIMIT 1', [id]);
    if (v.rowCount === 0) return reply.code(404).send({ error: 'Unknown video' });

    const { rows } = await query(
      `INSERT INTO video_comments (video_id, user_id, body)
       VALUES ($1,$2,$3)
       RETURNING id, created_at`,
      [id, userId, body]
    );

    return reply.send({ ok: true, comment: rows[0] });
  });

  // Delete a comment (author only)
  app.delete('/v1/videos/:id/comment/:commentId', async (req, reply) => {
    const Q = z.object({
      id: z.string().uuid(),
      commentId: z.string().uuid(),
      userId: z.string().uuid() // pass ?userId=... in query
    });

    const qp = Q.safeParse({ ...req.params, ...req.query });
    if (!qp.success) return reply.code(400).send({ error: 'Bad Request', issues: qp.error.issues });

    const { commentId, userId } = qp.data;
    // author-only hard delete for now (easy to switch to soft-delete later)
    await query('DELETE FROM video_comments WHERE id=$1 AND user_id=$2', [commentId, userId]);
    return reply.send({ ok: true });
  });
}
