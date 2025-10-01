import Fastify from 'fastify';
import cors from '@fastify/cors';
import { query } from './db.js';

import health from './routes/health.js';
import follow from './routes/follow.js';
import feed from './routes/feed.js';
import posts from './routes/posts.js';
import videos from './routes/videos.js';
import trending from './routes/trending.js';
import trendingDebug from './routes/trending_debug.js';

// NEW: engagement routes
import videoLikes from './routes/video_likes.js';
import videoComments from './routes/video_comments.js';

const app = Fastify({ logger: false });
await app.register(cors, { origin: '*' });

await health(app);
await follow(app);
await feed(app);
await posts(app);
await videos(app);
await videoLikes(app);      // 👈 now registered
await videoComments(app);   // 👈 now registered
await trending(app);
await trendingDebug(app);

// DB ping at boot
app.ready(async () => {
  try { await query('SELECT 1'); console.log('DB OK'); }
  catch (e) { console.error('DB ERR', e); }
});

const port = process.env.PORT || 8080;
app.listen({ host: '0.0.0.0', port }).then(() => {
  console.log('API up on :', port);
});
