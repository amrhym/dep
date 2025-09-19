#!/bin/bash

echo "🚀 Chatwoot Docker Setup with host.docker.internal"
echo "================================================"
echo ""

# Check if services are running on host
check_service() {
    local service=$1
    local port=$2
    
    if nc -z localhost $port 2>/dev/null; then
        echo "✅ $service is running on port $port"
        return 0
    else
        echo "❌ $service is not running on port $port"
        return 1
    fi
}

echo "Checking required services on host..."
echo ""

POSTGRES_OK=$(check_service "PostgreSQL" 5432 && echo 1 || echo 0)
REDIS_OK=$(check_service "Redis" 6379 && echo 1 || echo 0)

echo ""

# Start PostgreSQL if not running
if [ "$POSTGRES_OK" = "0" ]; then
    echo "Starting PostgreSQL on host..."
    echo "You can run PostgreSQL using Docker:"
    echo ""
    echo "docker run -d \\"
    echo "  --name postgres-host \\"
    echo "  -e POSTGRES_PASSWORD=28d6f8da48cf9cbaf8ab768475d64242598325ac232f4638 \\"
    echo "  -e POSTGRES_DB=chatwoot_production \\"
    echo "  -p 5432:5432 \\"
    echo "  pgvector/pgvector:pg16"
    echo ""
fi

# Start Redis if not running
if [ "$REDIS_OK" = "0" ]; then
    echo "Starting Redis on host..."
    echo "You can run Redis using Docker:"
    echo ""
    echo "docker run -d \\"
    echo "  --name redis-host \\"
    echo "  -p 6379:6379 \\"
    echo "  redis:alpine redis-server --requirepass 97d808d2b192117ecec966e85056117f"
    echo ""
fi

# Optional services
echo "Optional services (MailHog for email testing):"
echo "docker run -d \\"
echo "  --name mailhog-host \\"
echo "  -p 1025:1025 \\"
echo "  -p 8025:8025 \\"
echo "  mailhog/mailhog"
echo ""

echo "================================================"
echo "🏗️  Building and Running Chatwoot"
echo ""

# Build the image
echo "Building Chatwoot image..."
docker-compose -f docker-compose.host.yml build

# Run database migrations
echo ""
echo "Running database setup and migrations..."
docker-compose -f docker-compose.host.yml run --rm chatwoot bundle exec rails db:chatwoot_prepare

# Apply enterprise bypass
echo ""
echo "Applying enterprise bypass..."
docker-compose -f docker-compose.host.yml run --rm chatwoot bundle exec rails enterprise:bypass

# Start services
echo ""
echo "Starting Chatwoot services..."
docker-compose -f docker-compose.host.yml up -d

echo ""
echo "================================================"
echo "✅ Setup Complete!"
echo ""
echo "Chatwoot is now running at: http://localhost:3000"
echo ""
echo "Services connected via host.docker.internal:"
echo "  - PostgreSQL: host.docker.internal:5432"
echo "  - Redis: host.docker.internal:6379"
echo "  - MailHog: host.docker.internal:1025 (SMTP)"
echo "  - MailHog UI: http://localhost:8025"
echo ""
echo "To check logs:"
echo "  docker-compose -f docker-compose.host.yml logs -f"
echo ""
echo "To stop services:"
echo "  docker-compose -f docker-compose.host.yml down"
echo ""