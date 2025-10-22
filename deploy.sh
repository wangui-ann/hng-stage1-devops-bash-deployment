#!/bin/bash
set -euo pipefail
trap 'echo "❌ Error on line $LINENO"; exit 1' ERR

LOG_FILE="deploy_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "$(date '+%Y-%m-%d %H:%M:%S') 🚀 Starting deployment"

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
  echo "$(date '+%Y-%m-%d %H:%M:%S') ❌ All fields are required. Please provide valid inputs."
  exit 1
fi

# === SSH Connectivity Check ===
echo "$(date '+%Y-%m-%d %H:%M:%S') 🔐 Testing SSH connectivity..."
if ping -c 1 "$SSH_HOST" &>/dev/null; then
  echo "✅ Host reachable via ping"
else
  echo "❌ Host unreachable"
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') 🔐 Attempting SSH connection (placeholder)..."
if ssh -i ~/your-key.pem -o BatchMode=yes -o ConnectTimeout=5 "$SSH_USER@$SSH_HOST" "echo SSH connection successful" 2>/dev/null; then
  echo "✅ SSH connection established"
else
  echo "⚠️ SSH connection failed (placeholder)"
fi

# === Remote Command Execution ===
echo "$(date '+%Y-%m-%d %H:%M:%S') 🖥️ Executing remote command (placeholder)..."
if ssh -i ~/your-key.pem "$SSH_USER@$SSH_HOST" "echo Remote command executed" 2>/dev/null; then
  echo "✅ Remote command executed"
else
  echo "⚠️ Remote command failed (placeholder)"
fi

# === File Transfer Placeholder ===
echo "$(date '+%Y-%m-%d %H:%M:%S') 📤 Simulating file transfer..."
scp -r . "$SSH_USER@$SSH_HOST:/tmp/deployment" || echo "⚠️ File transfer placeholder"

# === Git Operations ===
REPO_NAME=$(basename "$REPO_URL" .git)
if [ -d "$REPO_NAME" ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') 📁 Repo exists. Pulling latest..."
  cd "$REPO_NAME"
  git fetch origin
  git checkout "$BRANCH"
  git pull origin "$BRANCH"
  if ! git diff-index --quiet HEAD --; then
    echo "⚠️ Uncommitted changes detected"
  fi
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') 📦 Cloning repository..."
  git clone -b "$BRANCH" https://$PAT@${REPO_URL#https://} "$REPO_NAME"
  cd "$REPO_NAME"
fi

# === Server Preparation ===
echo "$(date '+%Y-%m-%d %H:%M:%S') 🛠️ Installing dependencies..."
sudo apt-get update -y
sudo apt-get install -y docker.io docker-compose nginx curl dos2unix

echo "$(date '+%Y-%m-%d %H:%M:%S') 🔧 Configuring Docker and Nginx..."
sudo usermod -aG docker "$USER"
sudo systemctl enable docker
sudo systemctl start docker
sudo systemctl enable nginx
sudo systemctl start nginx

# === Docker Deployment ===
echo "$(date '+%Y-%m-%d %H:%M:%S') 🐳 Deploying Docker container..."
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
echo "$(date '+%Y-%m-%d %H:%M:%S') 🔍 Checking container health..."
if docker inspect app --format='{{.State.Health.Status}}' &>/dev/null; then
  docker inspect app --format='Health: {{.State.Health.Status}}'
else
  echo "⚠️ No health check configured or container not found"
fi

# === Nginx Configuration ===
echo "$(date '+%Y-%m-%d %H:%M:%S') 🌐 Configuring Nginx reverse proxy..."
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
echo "$(date '+%Y-%m-%d %H:%M:%S') 🔄 Testing and reloading Nginx..."
sudo nginx -t && sudo systemctl reload nginx

# === SSL Placeholder ===
echo "$(date '+%Y-%m-%d %H:%M:%S') 🔒 SSL setup placeholder — add Certbot or self-signed cert logic here if needed"

# === Deployment Validation ===
echo "$(date '+%Y-%m-%d %H:%M:%S') ✅ Validating deployment..."

echo "🔍 Checking Docker service..."
sudo systemctl status docker --no-pager

echo "🔍 Checking Nginx service..."
sudo systemctl status nginx --no-pager

echo "Running containers:"
docker ps

echo "Testing app endpoint locally:"
curl -s http://localhost | grep -i html && echo "✅ App is responding" || echo "⚠️ App may not be responding"

# === Idempotency & Cleanup ===
echo "$(date '+%Y-%m-%d %H:%M:%S') 🧹 Cleaning up unused Docker resources..."
docker container prune -f
docker image prune -f

echo "$(date '+%Y-%m-%d %H:%M:%S') 🎉 Deployment complete. Visit your EC2 public IP in a browser."
