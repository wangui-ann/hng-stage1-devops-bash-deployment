#!/bin/bash
set -euo pipefail
trap 'echo "❌ Error on line $LINENO"; exit 1' ERR

LOG_FILE="deploy_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "🚀 Starting deployment at $(date)"

# === User Input ===
read -p "Git Repository URL: " REPO_URL
read -p "Personal Access Token (PAT): " PAT
read -p "Branch name [default: main]: " BRANCH
BRANCH=${BRANCH:-main}
read -p "Application internal port (e.g., 5000): " APP_PORT
read -p "SSH Username (placeholder): " SSH_USER
read -p "SSH Host/IP (placeholder): " SSH_HOST

# === Validate Inputs ===
if [[ -z "$REPO_URL" || -z "$PAT" || -z "$APP_PORT" ]]; then
  echo "❌ All fields are required. Please provide valid inputs."
  exit 1
fi

# === Dummy SSH Connectivity Check ===
echo "🔐 Checking SSH connectivity (placeholder)..."
echo "SSH OK"

# === Git Operations ===
REPO_NAME=$(basename "$REPO_URL" .git)
if [ -d "$REPO_NAME" ]; then
  echo "📁 Repo exists. Pulling latest..."
  cd "$REPO_NAME"
  git fetch origin
  git checkout "$BRANCH"
  git pull origin "$BRANCH"
else
  echo "📦 Cloning repository..."
  git clone -b "$BRANCH" https://$PAT@${REPO_URL#https://} "$REPO_NAME"
  cd "$REPO_NAME"
fi

# === Server Preparation ===
echo "🛠️ Installing dependencies..."
sudo apt-get update -y
sudo apt-get install -y docker.io docker-compose nginx curl dos2unix

echo "🔐 Configuring Docker and Nginx..."
sudo usermod -aG docker "$USER"
sudo systemctl enable docker
sudo systemctl start docker
sudo systemctl enable nginx
sudo systemctl start nginx

# === Docker Deployment ===
echo "🐳 Deploying Docker container..."
if [ -f "docker-compose.yml" ]; then
  docker-compose down || true
  docker-compose up -d --build
else
  docker stop app || true
  docker rm app || true
  docker build -t app .
  docker run -d --name app -p "$APP_PORT:$APP_PORT" app
fi

# === Basic Health Check ===
echo "🔍 Checking container health..."
if docker inspect app --format='{{.State.Health.Status}}' &>/dev/null; then
  docker inspect app --format='Health: {{.State.Health.Status}}'
else
  echo "⚠️ No health check configured or container not found"
fi

# === Nginx Configuration ===
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

# === SSL Placeholder ===
echo "🔒 SSL setup placeholder — add Certbot or self-signed cert logic here if needed"

# === Deployment Validation ===
echo "✅ Validating deployment..."
echo "Docker service status:"
sudo systemctl is-active docker

echo "Running containers:"
docker ps

echo "Nginx service status:"
sudo systemctl is-active nginx

echo "Testing app endpoint locally:"
curl -s http://localhost | grep -i html && echo "✅ App is responding" || echo "⚠️ App may not be responding"

# === Idempotency & Cleanup ===
echo "🧹 Cleaning up unused Docker resources..."
docker container prune -f
docker image prune -f

echo "🎉 Deployment complete. Visit your EC2 public IP in a browser."
