# ---- deps ----
FROM node:22 AS deps

# better-sqlite3 requires native compilation
RUN apt-get update && apt-get install -y python3 make g++ && rm -rf /var/lib/apt/lists/*

# Enable corepack and install pnpm
RUN corepack enable && corepack prepare pnpm@10.30.0 --activate

WORKDIR /app

# Install dependencies (compiles better-sqlite3 for Linux)
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY packages/api/package.json ./packages/api/package.json
ENV LEFTHOOK=0
RUN pnpm install --frozen-lockfile --ignore-scripts
RUN cd node_modules/.pnpm/better-sqlite3@*/node_modules/better-sqlite3 && npx --yes prebuild-install || npx --yes node-gyp rebuild --release

# ---- build ----
FROM deps AS build

COPY . .
RUN pnpm pkg delete scripts.prepare && pnpm run build:api

# ---- worker ----
# Utility container for data management (download, import, index).
# Shares the `data` named volume with the api container.
FROM node:22 AS worker

RUN corepack enable && corepack prepare pnpm@10.30.0 --activate

WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/packages/api/node_modules ./packages/api/node_modules

COPY packages/api/scripts ./packages/api/scripts
COPY packages/api/utils ./packages/api/utils
COPY packages/api/package.json ./packages/api/package.json

WORKDIR /app/packages/api

VOLUME ["/app/packages/api/data"]

# ---- runtime ----
FROM node:22-slim AS runtime

RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*

ARG PORT=3000

WORKDIR /app

COPY --from=build /app/packages/api/.output ./
COPY --from=deps /app/node_modules/.pnpm/better-sqlite3@*/node_modules/better-sqlite3/build/Release/better_sqlite3.node ./server/node_modules/better-sqlite3/build/better_sqlite3.node

# Runtime-configurable environment variables
# DATA_PATH  — path to the SQLite database file (default: /data/wiktionary.db)
# PORT       — HTTP server port (default: 3000)
# HOST       — HTTP server bind address (default: 0.0.0.0)
# DATA_DIR   — directory for worker scripts (download/import/index)
ENV DATA_PATH=/data/wiktionary.db \
    PORT=3000 \
    HOST=0.0.0.0

VOLUME ["/data"]

EXPOSE ${PORT}

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:${PORT}/health || exit 1

CMD ["node", "server/index.mjs"]