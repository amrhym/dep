#!/bin/bash

echo "🚀 Starting External Services for Chatwoot"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if services are already running
check_port() {
    if nc -z localhost $1 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Start PostgreSQL if not running
if check_port 5432; then
    echo -e "${YELLOW}PostgreSQL is already running on port 5432${NC}"
else
    echo -e "${GREEN}Starting PostgreSQL...${NC}"
    docker run -d \
        --name chatwoot-postgres \
        -e POSTGRES_DB=chatwoot_production \
        -e POSTGRES_USER=postgres \
        -e POSTGRES_PASSWORD=28d6f8da48cf9cbaf8ab768475d64242598325ac232f4638 \
        -p 5432:5432 \
        pgvector/pgvector:pg16
    
    # Wait for PostgreSQL to be ready
    echo "Waiting for PostgreSQL to be ready..."
    sleep 5
fi

# Start Redis WITHOUT password
if check_port 6379; then
    echo -e "${YELLOW}Redis is already running on port 6379${NC}"
else
    echo -e "${GREEN}Starting Redis (without password)...${NC}"
    docker run -d \
        --name chatwoot-redis \
        -p 6379:6379 \
        redis:alpine redis-server --bind 0.0.0.0
    
    sleep 2
fi

# Start MailHog (optional)
if check_port 1025; then
    echo -e "${YELLOW}MailHog is already running on port 1025${NC}"
else
    echo -e "${GREEN}Starting MailHog...${NC}"
    docker run -d \
        --name chatwoot-mailhog \
        -p 1025:1025 \
        -p 8025:8025 \
        mailhog/mailhog
fi

echo ""
echo "=========================================="
echo -e "${GREEN}✅ External services are ready!${NC}"
echo ""
echo "Services running:"
echo "  - PostgreSQL: localhost:5432"
echo "  - Redis: localhost:6379 (no password)"
echo "  - MailHog SMTP: localhost:1025"
echo "  - MailHog UI: http://localhost:8025"
echo ""
echo "Now you can run Chatwoot with:"
echo "  docker compose -f docker-compose.selfhost.yml up -d"
echo ""