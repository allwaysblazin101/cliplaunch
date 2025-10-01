import { z } from 'zod';

export default async function creators(app) {
  const Create = z.object({
    wallet: z.string().min(32).max(44),
    handle: z.string().min(3).max(20),
    displayName: z.string().min(1).max(60),
    bio: z.string().max(280).optional()
  });

  // Create or upsert a creator (stub; no DB here)
  app.post('/v1/creators', async (req, reply) => {
    const p = Create.safeParse(req.body);
    if (!p.success) return reply.code(400).send({ error: 'Bad Request', issues: p.error.issues });
    return {
      ok: true,
      creator: {
        id: 'demo',
        wallet: p.data.wallet,
        handle: p.data.handle,
        displayName: p.data.displayName,
        bio: p.data.bio ?? null,
        token_mint: null,
        created_at: new Date().toISOString()
      }
    };
  });

  // Read a creator by handle (stub)
  app.get('/v1/creators/:handle', async (req) => {
    const { handle } = req.params;
    return {
      creator: {
        id: 'demo',
        handle,
        display_name: 'Clip Demo',
        wallet: '111...111',
        created_at: new Date().toISOString()
      },
      latestVideo: null
    };
  });
}
