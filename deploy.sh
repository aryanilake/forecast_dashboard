#!/bin/bash

# METAR GUI v2 - Docker Deployment Helper Script
# This script helps with deploying the application using Docker

set -e

echo "==================================================="
echo "METAR GUI v2 - Docker Deployment Helper"
echo "==================================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    exit 1
fi

# Check if docker-compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Error: docker-compose is not installed${NC}"
    exit 1
fi

# Function to display menu
show_menu() {
    echo ""
    echo "Select an action:"
    echo "1) Build and start services"
    echo "2) Stop services"
    echo "3) View logs"
    echo "4) Check service health"
    echo "5) Initialize database"
    echo "6) Clear cache"
    echo "7) Restart services"
    echo "8) Update configuration"
    echo "9) Exit"
    echo ""
}

# Function to create .env file
create_env_file() {
    if [ ! -f .env ]; then
        echo -e "${YELLOW}Creating .env file from .env.example...${NC}"
        cp .env.example .env
        
        # Generate a random JWT secret
        JWT_SECRET=$(head -c 32 /dev/urandom | base64)
        sed -i "s/JWT_SECRET=.*/JWT_SECRET=$JWT_SECRET/" .env
        
        echo -e "${GREEN}.env file created successfully${NC}"
        echo -e "${YELLOW}Please review and update sensitive values in .env file${NC}"
    fi
}

# Function to build and start
build_and_start() {
    echo -e "${YELLOW}Building and starting services...${NC}"
    create_env_file
    docker-compose build
    docker-compose up -d
    echo -e "${GREEN}Services started${NC}"
    sleep 5
    check_health
}

# Function to stop services
stop_services() {
    echo -e "${YELLOW}Stopping services...${NC}"
    docker-compose down
    echo -e "${GREEN}Services stopped${NC}"
}

# Function to view logs
view_logs() {
    echo -e "${YELLOW}Showing logs (Press Ctrl+C to exit)...${NC}"
    docker-compose logs -f
}

# Function to check health
check_health() {
    echo -e "${YELLOW}Checking service health...${NC}"
    
    # Check if containers are running
    backend_status=$(docker-compose ps backend | grep -c "Up" || true)
    nginx_status=$(docker-compose ps nginx | grep -c "Up" || true)
    
    if [ "$backend_status" -eq 1 ]; then
        echo -e "${GREEN}✓ Backend is running${NC}"
    else
        echo -e "${RED}✗ Backend is not running${NC}"
    fi
    
    if [ "$nginx_status" -eq 1 ]; then
        echo -e "${GREEN}✓ Nginx is running${NC}"
    else
        echo -e "${RED}✗ Nginx is not running${NC}"
    fi
    
    # Check backend health endpoint
    if curl -s http://localhost:5000/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Backend API is healthy${NC}"
    else
        echo -e "${RED}✗ Backend API is not responding${NC}"
    fi
    
    # Check frontend
    if curl -s http://localhost:8080 > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Frontend is accessible${NC}"
    else
        echo -e "${RED}✗ Frontend is not accessible${NC}"
    fi
}

# Function to initialize database
init_database() {
    echo -e "${YELLOW}Initializing database...${NC}"
    docker-compose exec backend python -c "from app.backend.app import app; from app.backend.models import db; db.create_all()" || true
    echo -e "${GREEN}Database initialized${NC}"
}

# Function to clear cache
clear_cache() {
    echo -e "${YELLOW}Clearing cache...${NC}"
    rm -rf app/data/.cache/*
    echo -e "${GREEN}Cache cleared${NC}"
}

# Function to restart services
restart_services() {
    echo -e "${YELLOW}Restarting services...${NC}"
    docker-compose restart
    echo -e "${GREEN}Services restarted${NC}"
    sleep 3
    check_health
}

# Function to update configuration
update_configuration() {
    echo -e "${YELLOW}Opening .env for editing...${NC}"
    if command -v nano &> /dev/null; then
        nano .env
    elif command -v vi &> /dev/null; then
        vi .env
    else
        echo -e "${RED}No text editor found${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Restarting services with new configuration...${NC}"
    docker-compose restart
    check_health
}

# Main loop
while true; do
    show_menu
    read -p "Enter your choice [1-9]: " choice
    
    case $choice in
        1)
            build_and_start
            ;;
        2)
            stop_services
            ;;
        3)
            view_logs
            ;;
        4)
            check_health
            ;;
        5)
            init_database
            ;;
        6)
            clear_cache
            ;;
        7)
            restart_services
            ;;
        8)
            update_configuration
            ;;
        9)
            echo -e "${GREEN}Exiting...${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            ;;
    esac
done
