/**
 * Global in-memory state shared across routes.
 * This avoids Fastify plugin encapsulation issues.
 */
export const launches = new Map(); // key: mint, value: metadata
