import { z } from 'zod';
import { query } from '../db.js';

export default async function creatorsUpsert(app) {
  const Body = z.object({
    userId: z.string().uuid(),
    handle: z.string().min(2),
    wallet: z.string().min(3),
    bio: z.string().optional()
  });

  app.post('/v1/creators/upsert', async (req, reply) => {
    const p = Body.safeParse(req.body);
    if (!p.success) return reply.code(400).send({ error: 'Bad Request', issues: p.error.issues });
    const { userId, handle, wallet, bio } = p.data;

    const sql = `
      WITH upd AS (
        UPDATE creators SET handle=$2, wallet=$3, bio=$4
        WHERE user_id=$1
        RETURNING *
      ), ins AS (
        INSERT INTO creators (user_id, handle, wallet, bio)
        SELECT $1, $2, $3, $4
        WHERE NOT EXISTS (SELECT 1 FROM upd)
        RETURNING *
      )
      SELECT * FROM upd
      UNION ALL
      SELECT * FROM ins
      LIMIT 1;
    `;
    const { rows } = await query(sql, [userId, handle, wallet, bio ?? null]);
    return { ok: true, creator: rows[0] };
  });
}
