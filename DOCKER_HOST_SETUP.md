# Chatwoot Docker Setup with host.docker.internal

This guide explains how to run Chatwoot in Docker while connecting to PostgreSQL, Redis, and other services running either on the host machine or in separate Docker containers.

## Architecture Options

### Option 1: All Services in Docker Compose (Default)
Use `docker-compose.selfhost.yml` - All services run together in one compose stack.

### Option 2: External Services via host.docker.internal
Use `docker-compose.host.yml` - Chatwoot connects to services on the host.

### Option 3: Mixed Setup
Run some services in Docker, others on host machine.

## Setup Instructions

### Prerequisites
- Docker Desktop (Mac/Windows) or Docker Engine 20.10+ (Linux)
- `host.docker.internal` support (built-in on Mac/Windows, needs setup on Linux)

### For Linux Users
Add this to your Docker daemon config (`/etc/docker/daemon.json`):
```json
{
  "host-gateway-ip": "172.17.0.1"
}
```

Or add to docker-compose.yml:
```yaml
extra_hosts:
  - "host.docker.internal:host-gateway"
```

## Running External Services

### Method 1: Using docker-compose.external-services.yml
```bash
# Start all external services
docker-compose -f docker-compose.external-services.yml up -d

# Check services are running
docker ps
netstat -an | grep -E '5432|6379|1025'
```

### Method 2: Individual Docker Commands
```bash
# PostgreSQL with pgvector
docker run -d \
  --name postgres-host \
  -e POSTGRES_PASSWORD=28d6f8da48cf9cbaf8ab768475d64242598325ac232f4638 \
  -e POSTGRES_DB=chatwoot_production \
  -e POSTGRES_USER=postgres \
  -p 5432:5432 \
  pgvector/pgvector:pg16

# Redis
docker run -d \
  --name redis-host \
  -p 6379:6379 \
  redis:alpine redis-server \
    --requirepass 97d808d2b192117ecec966e85056117f \
    --bind 0.0.0.0

# MailHog
docker run -d \
  --name mailhog-host \
  -p 1025:1025 \
  -p 8025:8025 \
  mailhog/mailhog
```

### Method 3: Native Installation
Install PostgreSQL, Redis, etc., directly on your host machine and ensure they're listening on all interfaces (0.0.0.0) not just localhost.

## Running Chatwoot with host.docker.internal

### 1. Start External Services First
```bash
# Using the external services compose file
docker-compose -f docker-compose.external-services.yml up -d
```

### 2. Build Chatwoot Image
```bash
docker-compose -f docker-compose.host.yml build
```

### 3. Initialize Database
```bash
# Run migrations
docker-compose -f docker-compose.host.yml run --rm chatwoot \
  bundle exec rails db:chatwoot_prepare

# Apply enterprise bypass (optional)
docker-compose -f docker-compose.host.yml run --rm chatwoot \
  bundle exec rails enterprise:bypass
```

### 4. Start Chatwoot
```bash
docker-compose -f docker-compose.host.yml up -d
```

## Environment Variables

### Key Configuration (.env.host)
```bash
# PostgreSQL via host.docker.internal
POSTGRES_HOST=host.docker.internal
POSTGRES_PORT=5432
POSTGRES_USERNAME=postgres
POSTGRES_PASSWORD=28d6f8da48cf9cbaf8ab768475d64242598325ac232f4638
POSTGRES_DATABASE=chatwoot_production

# Redis via host.docker.internal
REDIS_URL=redis://:97d808d2b192117ecec966e85056117f@host.docker.internal:6379/0

# SMTP via host.docker.internal
SMTP_ADDRESS=host.docker.internal
SMTP_PORT=1025
```

## Troubleshooting

### Test Connectivity from Chatwoot Container
```bash
# Test PostgreSQL
docker-compose -f docker-compose.host.yml exec chatwoot \
  psql -h host.docker.internal -U postgres -d chatwoot_production -c "SELECT 1"

# Test Redis
docker-compose -f docker-compose.host.yml exec chatwoot \
  redis-cli -h host.docker.internal -a 97d808d2b192117ecec966e85056117f ping

# Test from Rails console
docker-compose -f docker-compose.host.yml exec chatwoot rails c
> ActiveRecord::Base.connection.execute("SELECT version()")
> Redis.new(url: ENV['REDIS_URL']).ping
```

### Common Issues

1. **Connection Refused**: Ensure services are listening on 0.0.0.0, not 127.0.0.1
2. **host.docker.internal not found**: Update Docker or add extra_hosts configuration
3. **Permission Denied**: Check PostgreSQL pg_hba.conf allows connections from Docker network
4. **Port Already in Use**: Change port mappings or stop conflicting services

### Check Service Bindings
```bash
# PostgreSQL
sudo netstat -tlnp | grep 5432
# Should show 0.0.0.0:5432 not 127.0.0.1:5432

# Redis
sudo netstat -tlnp | grep 6379
# Should show 0.0.0.0:6379 not 127.0.0.1:6379
```

## Security Considerations

⚠️ **Warning**: Binding services to 0.0.0.0 exposes them to all network interfaces. In production:

1. Use firewall rules to restrict access
2. Use strong passwords
3. Consider using Docker networks instead of host networking
4. Use SSL/TLS for database connections
5. Restrict PostgreSQL access in pg_hba.conf

## Quick Commands Reference

```bash
# Start external services
docker-compose -f docker-compose.external-services.yml up -d

# Start Chatwoot with host.docker.internal
docker-compose -f docker-compose.host.yml up -d

# View logs
docker-compose -f docker-compose.host.yml logs -f

# Stop everything
docker-compose -f docker-compose.host.yml down
docker-compose -f docker-compose.external-services.yml down

# Clean up
docker-compose -f docker-compose.host.yml down -v
docker-compose -f docker-compose.external-services.yml down -v
```

## Port Summary

| Service | Port | Purpose |
|---------|------|---------|
| Chatwoot | 3000 | Web application |
| PostgreSQL | 5432 | Database |
| Redis | 6379 | Cache & queues |
| MailHog SMTP | 1025 | Email sending |
| MailHog UI | 8025 | Email preview |