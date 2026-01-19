# Multi-stage build for Claude Code UI with Bedrock support
FROM node:22-slim AS builder

# Install build dependencies for native modules (better-sqlite3, bcrypt)
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    make \
    g++ \
    gcc \
    libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*

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
FROM node:22-slim

# Install runtime and build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    sqlite3 \
    git \
    curl \
    python3 \
    python3-pip \
    make \
    g++ \
    ca-certificates \
    fonts-freefont-ttf \
    && rm -rf /var/lib/apt/lists/*

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

# Create directories for node user
RUN mkdir -p /home/node/.claude/skills \
    && mkdir -p /home/node/.claude/downloads \
    && mkdir -p /home/node/.local/bin \
    && mkdir -p /tmp/slidev-cache

# Configure Claude Code default settings for node user
COPY claude-settings/settings.json /home/node/.claude/settings.json

# Install skills from repositories
WORKDIR /tmp

# Clone and install anthropics/skills
RUN git clone --depth 1 https://github.com/anthropics/skills.git && \
    cp -r skills/skills/* /home/node/.claude/skills/ && \
    rm -rf skills

# Clone and install ybalbert001/claude-code-aws-skills (includes excalidraw)
RUN git clone https://github.com/ybalbert001/claude-code-aws-skills.git aws-skills && \
    cp -r aws-skills/* /home/node/.claude/skills/ && \
    rm -rf aws-skills

# Install Python dependencies for all skills
RUN find /home/node/.claude/skills -name "requirements.txt" -exec pip3 install --break-system-packages -r {} \; || true

# Install Langfuse
RUN pip3 install --break-system-packages langfuse

# Install Node dependencies for all skills
RUN for dir in $(find /home/node/.claude/skills -name "package.json" -type f); do \
        cd "$(dirname "$dir")" && npm install || true; \
    done

# Install Playwright Chromium for excalidraw PNG export (Python version)
RUN if [ -d "/home/node/.claude/skills/excalidraw/scripts" ]; then \
        python3 -m playwright install chromium --with-deps || true; \
    fi

# Install Slidev CLI, types and Playwright globally for slidev export
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/playwright-browsers
RUN npm install -g playwright-chromium --force && \
    npm install -g @slidev/cli@52.10.1 @slidev/types --force && \
    npx playwright install chromium --with-deps

# Make Playwright browsers accessible to all users
RUN chmod -R 755 /opt/playwright-browsers

# Make Slidev CLI directory writable for Vite cache (needed by node user at runtime)
RUN chmod -R 777 /usr/local/lib/node_modules/@slidev

# Set environment variables for Bedrock
ENV CLAUDE_CODE_USE_BEDROCK=1
ENV AWS_REGION=us-east-1
ENV NODE_ENV=production
ENV PORT=3001

WORKDIR /app

# Set HOME and PATH for node user (for Claude Code installation)
ENV HOME=/home/node
ENV PATH="/home/node/.local/bin:${PATH}"

# Install Claude Code (will install to /home/node/.local/bin)
RUN curl -fsSL https://claude.ai/install.sh | bash

# Fix all permissions for node user
RUN chown -R node:node /home/node && \
    chown -R node:node /app && \
    chown -R node:node /tmp/slidev-cache

# Configure git safe.directory to avoid permission issues
RUN git config --system safe.directory '*'

# Switch to node user for runtime
USER node

EXPOSE 3001

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:3001/health || exit 1

CMD ["node", "server/index.js"]
