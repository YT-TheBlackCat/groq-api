#!/bin/bash
# uninstall.sh: Remove groq-api installation, venv, apikeys, and service
set -e

SERVICE_NAME=groq-api
WORKDIR=$(pwd)

# Stop and disable the systemd service if it exists
if systemctl list-units --full -all | grep -Fq "$SERVICE_NAME.service"; then
    echo "[groq-api] Stopping and disabling systemd service..."
    sudo systemctl stop $SERVICE_NAME || true
    sudo systemctl disable $SERVICE_NAME || true
    sudo rm -f /etc/systemd/system/$SERVICE_NAME.service
    sudo systemctl daemon-reload
fi

# Remove venv
if [ -d "venv" ]; then
    echo "[groq-api] Removing virtual environment..."
    rm -rf venv
fi

# Remove apikeys.json
if [ -f "apikeys.json" ]; then
    echo "[groq-api] Removing apikeys.json..."
    rm -f apikeys.json
fi

# Remove debug log
if [ -f "debug.log" ]; then
    echo "[groq-api] Removing debug.log..."
    rm -f debug.log
fi

# Remove __pycache__
if [ -d "__pycache__" ]; then
    echo "[groq-api] Removing __pycache__..."
    rm -rf __pycache__
fi

echo "[groq-api] Uninstallation complete."
