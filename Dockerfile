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

# Install runtime and build dependencies
RUN apk add --no-cache \
    sqlite \
    git \
    curl \
    python3 \
    py3-pip \
    make \
    g++ \
    bash

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

# Create Claude skills directory (will be used by node user)
RUN mkdir -p /home/node/.claude/skills

# Install Claude Code and add to PATH (installed as root, will be moved to node user)
RUN curl -fsSL https://claude.ai/install.sh | bash

# Configure Claude Code permissions (bypass for Docker environment)
# Official docs: https://code.claude.com/docs/en/settings
RUN mkdir -p /home/node/.claude && \
    cat > /home/node/.claude/settings.json <<'EOF'
{
  "permissions": {
    "defaultMode": "bypassPermissions"
  }
}
EOF

# Install skills from repositories
WORKDIR /tmp

# Clone and install anthropics/skills
RUN git clone https://github.com/anthropics/skills.git anthropics-skills && \
    # Copy top-level skills
    find anthropics-skills -maxdepth 1 -type d ! -name ".*" ! -name "anthropics-skills" ! -name "document-skills" -exec cp -r {} /home/node/.claude/skills/ \; && \
    # Copy files from top level
    find anthropics-skills -maxdepth 1 -type f -exec cp {} /home/node/.claude/skills/ \; 2>/dev/null || true && \
    # Copy skills from document-skills subdirectory to root level
    if [ -d "anthropics-skills/document-skills" ]; then \
        find anthropics-skills/document-skills -maxdepth 1 -type d ! -name ".*" ! -name "document-skills" -exec cp -r {} /home/node/.claude/skills/ \; ; \
    fi && \
    rm -rf anthropics-skills

# Clone and install ybalbert001/claude-code-aws-skills
RUN git clone https://github.com/ybalbert001/claude-code-aws-skills.git aws-skills && \
    cp -r aws-skills/* /home/node/.claude/skills/ && \
    rm -rf aws-skills

# Clone and install excalidraw skill
RUN git clone --depth 1 --filter=blob:none --sparse https://github.com/ryanquinn3/dotfiles.git && \
    cd dotfiles && \
    git sparse-checkout set claude/.claude/skills/excalidraw && \
    cp -r claude/.claude/skills/excalidraw /home/node/.claude/skills/ && \
    cd .. && \
    rm -rf dotfiles

# Install Python dependencies for all skills
RUN find /home/node/.claude/skills -name "requirements.txt" -exec pip3 install --break-system-packages -r {} \; || true

# Install Node dependencies for all skills
RUN for dir in $(find /home/node/.claude/skills -name "package.json" -type f); do \
        cd "$(dirname "$dir")" && npm install || true; \
    done

# Set environment variables for Bedrock
ENV CLAUDE_CODE_USE_BEDROCK=1
ENV AWS_REGION=us-east-1
ENV NODE_ENV=production

# Port configuration (can be overridden by docker-compose)
ENV PORT=3001

WORKDIR /app

# Move Claude Code from root to node user's home and fix symlinks
RUN mkdir -p /home/node/.local && \
    cp -r /root/.local/share /home/node/.local/ 2>/dev/null || true && \
    mkdir -p /home/node/.local/bin && \
    ln -s /home/node/.local/share/claude/versions/2.0.53 /home/node/.local/bin/claude

# Change ownership of all necessary directories to node user
RUN chown -R node:node /app && \
    chown -R node:node /home/node/.claude && \
    chown -R node:node /home/node/.local

# Set HOME and PATH for node user
ENV HOME=/home/node
ENV PATH="/home/node/.local/bin:${PATH}"

# Switch to node user
USER node

# Expose port (using PORT environment variable)
# Note: EXPOSE doesn't support environment variables directly, but the app uses $PORT
EXPOSE 3001

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:3001/health || exit 1

# Start server
CMD ["node", "server/index.js"]
