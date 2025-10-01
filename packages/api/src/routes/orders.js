import { z } from 'zod';
import { query, tx } from '../db.js';

export default async function orders(app) {
  // ---------- Build (already working) ----------
  const Build = z.object({
    mint: z.string().min(8),
    side: z.enum(['buy','sell']),
    amountIn: z.string().regex(/^\d+$/),
    payer: z.string().min(32),
  });

  app.post('/v1/orders/build', async (req, reply) => {
    const p = Build.safeParse(req.body);
    if (!p.success) return reply.code(400).send({ error:'Bad Request', issues:p.error.issues });
    const { mint, side, amountIn, payer } = p.data;

    const t = await query(
      `SELECT symbol, decimals, initial_supply, base_token
         FROM tokens WHERE mint=$1 LIMIT 1`, [mint]);
    if (t.rowCount === 0) return reply.code(404).send({ error:'TokenNotFound' });

    // toy curve
    const base = 0.5;
    const slope = 0.0000001;
    const circulating = Number(t.rows[0].initial_supply || 0);
    const price = base + slope * circulating;

    const amt = BigInt(amountIn);
    const out = (Build.shape.side._def.values.includes('buy') && (p.data.side === 'buy'))
      ? BigInt(Math.floor(Number(amt)/price))
      : BigInt(Math.floor(Number(amt)*price));

    const { rows } = await tx(async (c) => {
      const r = await c.query(
        `INSERT INTO orders (mint, side, amount_in, amount_out, price, status, payer)
         VALUES ($1,$2,$3,$4,$5,'preview',$6)
         RETURNING id, created_at`,
        [mint, side, String(amt), String(out), price, payer]
      );
      return r;
    });

    return reply.send({
      ok:true,
      orderId: rows[0].id,
      preview: {
        mint,
        symbol: t.rows[0].symbol,
        side,
        price: Number(price),
        amountIn: String(amt),
        out: side === 'buy' ? { tokenOut:String(out) } : { baseOut:String(out) },
        fees: { protocolBps:'0', creatorBps:'0', protocolBase:'0', creatorBase:'0' },
        recentBlockhash: 'stub-blockhash',
        note: 'Unsigned memo tx (placeholder). Next step: replace with real SPL + program Ixs.'
      }
    });
  });

  // ---------- Execute ----------
  const Exec = z.object({
    orderId: z.string().uuid()
  });

  app.post('/v1/orders/execute', async (req, reply) => {
    const p = Exec.safeParse(req.body);
    if (!p.success) return reply.code(400).send({ error:'Bad Request', issues:p.error.issues });

    const { orderId } = p.data;

    const result = await tx(async (c) => {
      // lock the order row
      const o = await c.query(
        `SELECT o.*, t.base_token
           FROM orders o
           JOIN tokens t ON t.mint = o.mint
          WHERE o.id=$1
          FOR UPDATE`,
        [orderId]
      );
      if (o.rowCount === 0) return { notFound:true };
      const ord = o.rows[0];
      if (ord.status !== 'preview') return { already:true, ord };

      // ledger: for BUY -> payer spends base, receives token
      const baseMint = ord.base_token;        // e.g. 'USDC'
      const tokenMint = ord.mint;
      const payer = ord.payer;

      await c.query(
        `INSERT INTO ledger_entries (owner, mint, delta, reason, order_id)
         VALUES
           ($1,$2, $3, 'order-exec', $5),
           ($1,$4, $6, 'order-exec', $5)`,
        [
          payer,
          baseMint,                // mint #1 (base)
          `-${ord.amount_in}`,     // delta #1 (spend base)
          tokenMint,               // mint #2 (creator token)
          orderId,
          `${ord.amount_out}`      // delta #2 (receive token)
        ]
      );

      const u = await c.query(`UPDATE orders SET status='executed' WHERE id=$1 RETURNING *`, [orderId]);
      return { ord: u.rows[0] };
    });

    if (result?.notFound) return reply.code(404).send({ error:'OrderNotFound' });
    if (result?.already)  return reply.send({ ok:true, order: result.ord });

    return reply.send({ ok:true, order: result.ord });
  });

  // ---------- Faucet (DEV ONLY) ----------
  const Faucet = z.object({
    owner: z.string().min(32),
    mint: z.string().min(3),            // e.g. 'USDC' or a creator mint
    amount: z.string().regex(/^\d+$/)
  });

  app.post('/v1/wallets/faucet', async (req, reply) => {
    const p = Faucet.safeParse(req.body);
    if (!p.success) return reply.code(400).send({ error:'Bad Request', issues:p.error.issues });
    const { owner, mint, amount } = p.data;

    await query(
      `INSERT INTO ledger_entries (owner, mint, delta, reason)
       VALUES ($1,$2,$3,'faucet')`,
      [owner, mint, amount]
    );
    return { ok:true };
  });
}
