import { z } from 'zod';
import { query } from '../db.js';

export default async function videos(app) {
  // Create (publish) a video
  app.post('/v1/videos', async (req, reply) => {
    const Q = z.object({
      userId: z.string().uuid(),                 // uploader
      title: z.string().min(1),
      description: z.string().default(''),
      hlsUrl: z.string().url(),                  // maps -> videos.playback_hls_url
      durationSeconds: z.coerce.number().int().nonnegative().default(0),
      visibility: z.coerce.number().int().min(0).max(2).default(0),
    });

    const p = Q.safeParse(req.body);
    if (!p.success) return reply.code(400).send({ error: 'Bad Request', issues: p.error.issues });

    const { userId, title, description, hlsUrl, durationSeconds, visibility } = p.data;

    const { rows } = await query(
      `INSERT INTO videos (user_id, title, description, playback_hls_url, duration_s, visibility)
       VALUES ($1,$2,$3,$4,$5,$6)
       RETURNING id, user_id, title, description, playback_hls_url, duration_s, visibility, created_at`,
      [userId, title, description, hlsUrl, durationSeconds, visibility]
    );

    return reply.send({ ok: true, video: rows[0] });
  });

  // Get one video
  app.get('/v1/videos/:id', async (req, reply) => {
    const { id } = req.params;
    const { rows } = await query(
      `SELECT v.*, u.handle AS creator_handle
       FROM videos v
       JOIN users u ON u.id = v.user_id
       WHERE v.id = $1`, [id]
    );
    if (!rows.length) return reply.code(404).send({ error: 'Not Found' });
    return reply.send({ ok: true, video: rows[0] });
  });

  // List by handle (simple)
  app.get('/v1/videos', async (req, reply) => {
    const { handle, limit = 10 } = req.query;
    if (!handle) return reply.code(400).send({ error: 'handle required' });
    const { rows } = await query(
      `SELECT v.*, u.handle AS creator_handle
       FROM users u
       JOIN videos v ON v.user_id = u.id
       WHERE u.handle = $1
       ORDER BY v.created_at DESC
       LIMIT GREATEST(1, LEAST($2::int, 50))`,
      [handle, limit]
    );
    return reply.send({ ok: true, items: rows });
  });
}
