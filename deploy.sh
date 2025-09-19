#!/bin/bash

echo "🚀 Chatwoot Deployment Script"
echo "============================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
IMAGE="amrhym/dep:latest"
COMPOSE_FILE="docker-compose.deploy.yml"

# Function to check command status
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $1${NC}"
    else
        echo -e "${RED}✗ $1 failed${NC}"
        exit 1
    fi
}

# Parse command line arguments
COMMAND=${1:-deploy}
TAG=${2:-latest}

case $COMMAND in
    deploy|update)
        echo -e "${BLUE}📦 Pulling latest image...${NC}"
        docker pull $IMAGE
        check_status "Image pull"

        echo -e "${BLUE}🔄 Updating containers...${NC}"
        docker-compose -f $COMPOSE_FILE up -d
        check_status "Container update"

        echo -e "${BLUE}🗃️ Running database migrations...${NC}"
        docker-compose -f $COMPOSE_FILE exec -T chatwoot bundle exec rails db:migrate
        check_status "Database migration"

        echo -e "${BLUE}🔧 Applying enterprise bypass...${NC}"
        docker-compose -f $COMPOSE_FILE exec -T chatwoot bundle exec rails enterprise:bypass
        check_status "Enterprise bypass"

        echo -e "${BLUE}🧹 Cleaning up old images...${NC}"
        docker image prune -f
        check_status "Image cleanup"

        echo ""
        echo -e "${GREEN}✅ Deployment complete!${NC}"
        ;;

    rollback)
        echo -e "${YELLOW}⏮️ Rolling back to previous version...${NC}"
        docker-compose -f $COMPOSE_FILE down
        docker pull amrhym/dep:${TAG}
        docker tag amrhym/dep:${TAG} amrhym/dep:latest
        docker-compose -f $COMPOSE_FILE up -d
        check_status "Rollback"
        ;;

    stop)
        echo -e "${YELLOW}⏹️ Stopping services...${NC}"
        docker-compose -f $COMPOSE_FILE down
        check_status "Stop services"
        ;;

    start)
        echo -e "${GREEN}▶️ Starting services...${NC}"
        docker-compose -f $COMPOSE_FILE up -d
        check_status "Start services"
        ;;

    restart)
        echo -e "${YELLOW}🔄 Restarting services...${NC}"
        docker-compose -f $COMPOSE_FILE restart
        check_status "Restart services"
        ;;

    logs)
        echo -e "${BLUE}📋 Showing logs...${NC}"
        docker-compose -f $COMPOSE_FILE logs -f
        ;;

    status)
        echo -e "${BLUE}📊 Service status:${NC}"
        docker-compose -f $COMPOSE_FILE ps
        echo ""
        echo -e "${BLUE}🏥 Health checks:${NC}"
        docker-compose -f $COMPOSE_FILE exec chatwoot curl -s http://localhost:3000/api || echo "API not responding"
        ;;

    backup)
        echo -e "${BLUE}💾 Creating backup...${NC}"
        BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
        mkdir -p $BACKUP_DIR
        
        # Backup database
        docker-compose -f $COMPOSE_FILE exec -T postgres pg_dump -U postgres chatwoot_production > $BACKUP_DIR/database.sql
        check_status "Database backup"
        
        # Backup storage
        docker run --rm -v chatwoot_storage_data:/data -v $(pwd)/$BACKUP_DIR:/backup alpine tar czf /backup/storage.tar.gz -C /data .
        check_status "Storage backup"
        
        echo -e "${GREEN}✅ Backup created in $BACKUP_DIR${NC}"
        ;;

    restore)
        if [ -z "$2" ]; then
            echo -e "${RED}Please specify backup directory${NC}"
            echo "Usage: $0 restore backups/YYYYMMDD_HHMMSS"
            exit 1
        fi
        
        BACKUP_DIR=$2
        echo -e "${YELLOW}⚠️  Restoring from $BACKUP_DIR${NC}"
        echo "This will overwrite current data. Continue? (y/N)"
        read -r response
        
        if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            # Restore database
            docker-compose -f $COMPOSE_FILE exec -T postgres psql -U postgres chatwoot_production < $BACKUP_DIR/database.sql
            check_status "Database restore"
            
            # Restore storage
            docker run --rm -v chatwoot_storage_data:/data -v $(pwd)/$BACKUP_DIR:/backup alpine tar xzf /backup/storage.tar.gz -C /data
            check_status "Storage restore"
            
            echo -e "${GREEN}✅ Restore complete${NC}"
        else
            echo "Restore cancelled"
        fi
        ;;

    shell)
        echo -e "${BLUE}🐚 Opening shell in Chatwoot container...${NC}"
        docker-compose -f $COMPOSE_FILE exec chatwoot bash
        ;;

    console)
        echo -e "${BLUE}💎 Opening Rails console...${NC}"
        docker-compose -f $COMPOSE_FILE exec chatwoot bundle exec rails c
        ;;

    *)
        echo "Usage: $0 {deploy|rollback|stop|start|restart|logs|status|backup|restore|shell|console} [tag]"
        echo ""
        echo "Commands:"
        echo "  deploy    - Deploy latest version"
        echo "  rollback  - Rollback to specific tag"
        echo "  stop      - Stop all services"
        echo "  start     - Start all services"
        echo "  restart   - Restart all services"
        echo "  logs      - Show service logs"
        echo "  status    - Show service status"
        echo "  backup    - Create backup"
        echo "  restore   - Restore from backup"
        echo "  shell     - Open bash shell in container"
        echo "  console   - Open Rails console"
        exit 1
        ;;
esac

echo ""
echo "Container status:"
docker ps | grep chatwoot || echo "No Chatwoot containers running"