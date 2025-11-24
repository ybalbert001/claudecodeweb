# Multi-stage build for Claude Code UI with Bedrock support
FROM node:20-alpine AS builder

# Install build dependencies for native modules (better-sqlite3, bcrypt)
RUN apk add --no-cache \
    python3 \
    make \
    g++ \
    gcc \
    libc-dev \
    sqlite-dev

WORKDIR /app

# Copy package files
COPY claudecodeui/package*.json ./

# Install dependencies (including dev dependencies for build)
RUN npm ci

# Copy source code
COPY claudecodeui/ .

# Build frontend
RUN npm run build

# Production stage
FROM node:20-alpine

# Install runtime dependencies
RUN apk add --no-cache \
    sqlite \
    git \
    curl

WORKDIR /app

# Copy package files
COPY claudecodeui/package*.json ./

# Install production dependencies only
RUN npm ci --production

# Copy built files from builder
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/server ./server

# Create directory for database and projects
RUN mkdir -p /app/data /app/projects

# Set environment variables for Bedrock
ENV CLAUDE_CODE_USE_BEDROCK=1
ENV PORT=3001
ENV NODE_ENV=production

# Expose port
EXPOSE 3001

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:3001/health || exit 1

# Start server
CMD ["node", "server/index.js"]
