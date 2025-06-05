#!/bin/bash
# install-service.sh: Install groq-api as a systemd service
set -e

SERVICE_NAME=groq-api
WORKDIR=$(pwd)
USER=$(whoami)

cat <<EOF | sudo tee /etc/systemd/system/$SERVICE_NAME.service
[Unit]
Description=Groq API FastAPI Proxy Service
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$WORKDIR
ExecStart=$WORKDIR/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME
sudo systemctl start $SERVICE_NAME

echo "[groq-api] Service installed and started. Use 'sudo systemctl status $SERVICE_NAME' to check status."
