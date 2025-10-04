# Dev image for running API + scripts with pnpm workspaces
FROM node:20-bullseye

# pnpm via corepack
RUN corepack enable

WORKDIR /app

# Install OS tooling you likely use in scripts (psql via postgres-client, curl, jq)
RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-client curl jq ca-certificates git \
 && rm -rf /var/lib/apt/lists/*

# Copy workspace files up front (better layer caching)
COPY pnpm-workspace.yaml ./
COPY package.json ./
# If you have a lockfile, include it for reliable installs (optional but recommended)
# COPY pnpm-lock.yaml ./

# Copy package manifests used for install
COPY packages/api/package.json packages/api/

# Install workspace deps
RUN pnpm install --frozen-lockfile || pnpm install

# Bring the whole repo (source, scripts, sql, etc.)
COPY . .

# Default env
ENV NODE_ENV=development \
    PORT=8080

# Expose API port
EXPOSE 8080

# Default command runs API from the workspace
CMD ["pnpm","-C","packages/api","dev"]
