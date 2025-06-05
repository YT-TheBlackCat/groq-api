#!/bin/bash
set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SERVICE_NAME=groq-api

echo -e "${YELLOW}[groq-api] Stopping service...${NC}"
sudo systemctl stop $SERVICE_NAME

echo -e "${GREEN}[groq-api] Service stopped. Check status with: sudo systemctl status $SERVICE_NAME${NC}"

