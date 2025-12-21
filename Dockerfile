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

# Create Claude skills directory
RUN mkdir -p /root/.claude/skills

# Configure Claude Code default settings (bypass for Docker environment)
COPY claude-settings/settings.json /root/.claude/settings.json

# Install skills from repositories
WORKDIR /tmp

# Clone and install anthropics/skills
RUN git clone --depth 1 https://github.com/anthropics/skills.git && \
    cp -r skills/skills/* /root/.claude/skills/ && \
    rm -rf skills

# Clone and install ybalbert001/claude-code-aws-skills (includes excalidraw)
RUN git clone https://github.com/ybalbert001/claude-code-aws-skills.git aws-skills && \
    cp -r aws-skills/* /root/.claude/skills/ && \
    rm -rf aws-skills

# Install Python dependencies for all skills
RUN find /root/.claude/skills -name "requirements.txt" -exec pip3 install --break-system-packages -r {} \; || true

# Install Node dependencies for all skills
RUN for dir in $(find /root/.claude/skills -name "package.json" -type f); do \
        cd "$(dirname "$dir")" && npm install || true; \
    done

# Install Playwright Chromium for excalidraw PNG export (Python version)
RUN if [ -d "/root/.claude/skills/excalidraw/scripts" ]; then \
        python3 -m playwright install chromium --with-deps || true; \
    fi

# Install Slidev CLI and Playwright globally for slidev export
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/playwright-browsers
RUN npm install -g playwright-chromium --force && \
    npm install -g @slidev/cli@52.10.1 --force && \
    npx playwright install chromium --with-deps

# Set environment variables for Bedrock
ENV CLAUDE_CODE_USE_BEDROCK=1
ENV AWS_REGION=us-east-1
ENV NODE_ENV=production
ENV PORT=3001

WORKDIR /app

# Set HOME and PATH for root user
ENV HOME=/root
ENV PATH="/root/.local/bin:${PATH}"

# Install Claude Code
RUN curl -fsSL https://claude.ai/install.sh | bash

EXPOSE 3001

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:3001/health || exit 1

CMD ["node", "server/index.js"]
