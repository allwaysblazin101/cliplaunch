import { z } from 'zod';
import { query } from '../db.js';

export default async function social(app) {
  // Create/update user (dev helper)
  const NewUser = z.object({
    handle: z.string().min(2),
    displayName: z.string().min(1),
    avatarUrl: z.string().url().optional(),
    bio: z.string().optional()
  });

  app.post('/v1/users', async (req, reply) => {
    const p = NewUser.safeParse(req.body);
    if (!p.success) return reply.code(400).send({ error: 'Bad Request', issues: p.error.issues });
    const { handle, displayName, avatarUrl, bio } = p.data;
    const { rows } = await query(
      `INSERT INTO users (handle, display_name, avatar_url, bio)
       VALUES ($1,$2,$3,$4)
       ON CONFLICT (handle) DO UPDATE
         SET display_name=EXCLUDED.display_name,
             avatar_url=EXCLUDED.avatar_url,
             bio=EXCLUDED.bio
       RETURNING *`,
      [handle, displayName, avatarUrl ?? null, bio ?? null]
    );
    return { ok: true, user: rows[0] };
  });

  // Follow
  const Follow = z.object({ follower: z.string().uuid(), followee: z.string().uuid() });
  app.post('/v1/follow', async (req, reply) => {
    const p = Follow.safeParse(req.body);
    if (!p.success) return reply.code(400).send({ error: 'Bad Request', issues: p.error.issues });
    const { follower, followee } = p.data;
    await query(
      `INSERT INTO follows (follower_id, followee_id)
       VALUES ($1,$2)
       ON CONFLICT DO NOTHING`,
      [follower, followee]
    );
    return { ok: true };
  });
}
