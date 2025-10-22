#!/bin/bash
set -e

APP_PORT=5000
APP_DIR=$(pwd)

echo "🔧 Updating system and installing dependencies..."
sudo apt-get update -y
sudo apt-get install -y docker.io docker-compose nginx curl dos2unix

echo "🔐 Adding user to Docker group..."
sudo usermod -aG docker ubuntu

echo "🐳 Building and running Docker container..."
if [ -f "docker-compose.yml" ]; then
    docker-compose down || true
    docker-compose up -d --build
else
    docker stop app || true
    docker rm app || true
    docker build -t app .
    docker run -d --name app -p $APP_PORT:$APP_PORT app
fi

echo "🌐 Configuring Nginx reverse proxy..."
sudo tee /etc/nginx/sites-available/app.conf > /dev/null <<NGINX
server {
    listen 80;
    location / {
        proxy_pass http://localhost:$APP_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
NGINX

sudo ln -sf /etc/nginx/sites-available/app.conf /etc/nginx/sites-enabled/app.conf
sudo nginx -t && sudo systemctl reload nginx

echo "🔍 Validating deployment..."
curl -s http://localhost | grep -i html && echo "✅ Deployment successful" || echo "⚠️ App may not be responding"
