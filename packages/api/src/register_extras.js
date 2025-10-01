import authPlugin from './plugins/auth.js';
import authRoutes from './routes/auth.js';
export async function registerExtras(app) {
  await app.register(authPlugin);
  await app.register(authRoutes);
}
