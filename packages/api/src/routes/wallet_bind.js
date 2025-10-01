import { z } from 'zod';
import { query } from '../db.js';

export default async function walletBind(app) {
  const Body = z.object({
    owner: z.string().min(32),   // public key
    userId: z.string().uuid()
  });

  app.post('/v1/wallets/bind', async (req, reply) => {
    const p = Body.safeParse(req.body);
    if (!p.success) return reply.code(400).send({ error: 'Bad Request', issues: p.error.issues });

    const { owner, userId } = p.data;
    await query(
      `INSERT INTO wallet_owners (owner, user_id)
       VALUES ($1,$2)
       ON CONFLICT (owner) DO UPDATE SET user_id=EXCLUDED.user_id`,
      [owner, userId]
    );
    return { ok: true };
  });
}
