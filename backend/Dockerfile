# ==============================================================================
# ZankoAI Production Multi-Stage Dockerfile (Node.js 22+ Alpine)
# ==============================================================================

# --- Stage 1: Build & Compile TypeScript ---
FROM node:22-alpine AS builder

WORKDIR /app

COPY package*.json tsconfig.json ./

RUN npm ci

COPY src ./src

RUN npm run build

# --- Stage 2: Production Minimal Runner ---
FROM node:22-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production

COPY package*.json ./

# Install only production dependencies
RUN npm ci --only=production && npm cache clean --force

# Copy compiled JavaScript output
COPY --from=builder /app/dist ./dist

# Create a non-root user for security
USER node

# Default port
EXPOSE 4000

# Start production API server
CMD ["node", "dist/server.js"]
