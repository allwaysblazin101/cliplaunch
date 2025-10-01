import { z } from 'zod';
import { query } from '../db.js';

export default async function launch(app) {
  const Body = z.object({
    wallet: z.string().min(32).max(44),
    symbol: z.string().min(1).max(10),
    decimals: z.number().int().min(0).max(9).default(9),
    initialSupply: z.string().regex(/^[0-9]+$/),
    handle: z.string().min(3).max(20)
  });

  app.post('/v1/creators/launch', async (req, reply) => {
    const p = Body.safeParse(req.body);
    if (!p.success) return reply.code(400).send({ error: 'Bad Request', issues: p.error.issues });

    const { wallet, symbol, decimals, initialSupply, handle } = p.data;

    // Resolve creator
    const c = await query(`select id, wallet from creators where handle=$1`, [handle]);
    if (!c.rowCount) return reply.code(404).send({ error: 'CreatorNotFound' });

    // Simple stub “mint” id (replace with real base58 once SPL mint exists)
    const mint = 'M' + Buffer.from(`${handle}:${Date.now()}`).toString('base64url').slice(0,31);

    // Persist
    const ins = `
      insert into tokens(mint, creator_id, symbol, decimals, initial_supply, curve)
      values ($1,$2,$3,$4,$5,$6)
      returning mint, creator_id, symbol, decimals, initial_supply, curve, created_at
    `;
    const { rows } = await query(ins, [mint, c.rows[0].id, symbol, decimals, initialSupply, 'linear-stub']);

    return {
      ok: true,
      launched: {
        mint: rows[0].mint,
        wallet,
        symbol: rows[0].symbol,
        decimals: rows[0].decimals,
        initialSupply: rows[0].initial_supply,
        curve: rows[0].curve,
        created_at: rows[0].created_at
      },
      note: 'Stub launch persisted. Next: replace mint with real SPL token + metadata.'
    };
  });

  // Lookup token metadata
  app.get('/v1/tokens/:mint', async (req, reply) => {
    const t = await query(`select t.*, c.handle from tokens t join creators c on c.id=t.creator_id where t.mint=$1`, [req.params.mint]);
    if (!t.rowCount) return reply.code(404).send({ error: 'NotFound' });
    return t.rows[0];
  });
}
