import Fastify from 'fastify';
import health from './routes/health.js';
import creators from './routes/creators.js';
import videos from './routes/videos.js';
import posts from './routes/posts.js';
import follows from './routes/follows.js';
import feed from './routes/feed.js';
import orders from './routes/orders.js';
import trending from './routes/trending.js';

const app = Fastify({ logger: false });

await health(app);
await creators(app);
await videos(app);
await posts(app);
await follows(app);
await feed(app);
await orders(app);
await trending(app);

const PORT = process.env.PORT ? Number(process.env.PORT) : 8080;
const HOST = process.env.HOST || '0.0.0.0';

app.listen({ port: PORT, host: HOST })
  .then(() => console.log(`API up on ${HOST}:${PORT}`))
  .catch((err) => {
    console.error('Failed to start API:', err);
    process.exit(1);
  });
