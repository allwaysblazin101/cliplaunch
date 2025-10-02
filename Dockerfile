FROM node:20-slim

WORKDIR /app
COPY pnpm-lock.yaml pnpm-workspace.yaml package.json ./ 
COPY packages ./packages
COPY scripts ./scripts
COPY sql ./sql

RUN corepack enable && corepack prepare pnpm@9.0.0 --activate
RUN pnpm install --frozen-lockfile

ENV PORT=8080
EXPOSE 8080

CMD ["pnpm","--filter","packages/api","dev"]
