#!/bin/bash

# Claude Code UI Docker Deployment Script
# This script helps deploy Claude Code UI with user-specific configurations

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if username is provided
if [ -z "$1" ]; then
    print_error "Username is required!"
    echo "Usage: $0 <username> [port]"
    echo "Example: $0 john 3001"
    exit 1
fi

USERNAME=$1
PORT=${2:-3001}

print_info "Starting Claude Code UI for user: $USERNAME on port: $PORT"

# Create user-specific workspace directory if it doesn't exist
USER_WORKSPACE="/home/ubuntu/cc-user/${USERNAME}"
if [ ! -d "$USER_WORKSPACE" ]; then
    print_warning "Creating user workspace directory: $USER_WORKSPACE"
    mkdir -p "$USER_WORKSPACE"
fi

# Create data directory for user database
USER_DATA="./data/${USERNAME}"
if [ ! -d "$USER_DATA" ]; then
    print_warning "Creating user data directory: $USER_DATA"
    mkdir -p "$USER_DATA"
fi

# Check if AWS credentials are set
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    print_warning "AWS credentials not found in environment variables"
    print_info "Please ensure AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are set"

    # Check if .env file exists
    if [ ! -f ".env" ]; then
        print_warning "No .env file found. Creating template..."
        cat > .env <<EOF
# AWS Credentials
AWS_ACCESS_KEY_ID=your-access-key-id
AWS_SECRET_ACCESS_KEY=your-secret-access-key
# AWS_SESSION_TOKEN=your-session-token  # Optional for temporary credentials

# Optional: Bedrock Gateway
# ANTHROPIC_BEDROCK_BASE_URL=your-gateway-url
# CLAUDE_CODE_SKIP_BEDROCK_AUTH=1
EOF
        print_info "Please edit .env file with your AWS credentials"
        exit 1
    fi
fi

# Export environment variables
export USERNAME=$USERNAME
export PORT=$PORT

# Build and start the container
print_info "Building and starting Docker container..."
docker-compose up -d --build

# Wait for health check
print_info "Waiting for service to be healthy..."
sleep 10

# Check container status
CONTAINER_NAME="claude-code-ui-${USERNAME}"
if docker ps | grep -q "$CONTAINER_NAME"; then
    print_info "Claude Code UI is running successfully!"
    print_info "Access the UI at: http://localhost:${PORT}"
    print_info "User workspace: ${USER_WORKSPACE}"
    print_info ""
    print_info "To view logs: docker logs -f ${CONTAINER_NAME}"
    print_info "To stop: docker stop ${CONTAINER_NAME}"
    print_info "To remove: docker rm ${CONTAINER_NAME}"
else
    print_error "Failed to start container. Check logs with:"
    print_error "docker logs ${CONTAINER_NAME}"
    exit 1
fi
