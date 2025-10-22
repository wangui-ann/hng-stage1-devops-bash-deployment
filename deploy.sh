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
read -p "Remote SSH Username: " SSH_USER
read -p "Remote Server IP: " SERVER_IP
read -p "SSH Key Path (e.g., ~/hng.pem): " SSH_KEY
read -p "Application internal port (e.g., 5000): " APP_PORT

# === Validate Inputs ===
[[ -z "$REPO_URL" || -z "$PAT" || -z "$SSH_USER" || -z "$SERVER_IP" || -z "$SSH_KEY" || -z "$APP_PORT" ]] && {
  echo "❌ All fields are required."
  exit 1
}

# === SSH Check ===
echo "🔐 Checking SSH connectivity..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@$SERVER_IP" "echo SSH OK" || {
  echo "❌ SSH connection failed"
  exit 1
}

# === Git Clone ===
REPO_NAME=$(basename "$REPO_URL" .git)
echo "📦 Cloning repository..."
ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" bash <<EOF
  set -e
  if [ -d "$REPO_NAME" ]; then
    cd "$REPO_NAME"
    git pull origin "$BRANCH"
  else
    git clone -b "$BRANCH" https://$PAT@${REPO_URL#https://} "$REPO_NAME"
  fi
EOF

# === Remote Setup ===
echo "🛠️ Preparing remote server..."
ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" bash <<EOF
  set -e
  sudo apt-get update -y
  sudo apt-get install -y docker.io docker-compose nginx curl dos2unix
  sudo usermod -aG docker $SSH_USER
  sudo systemctl enable docker
  sudo systemctl start docker
  sudo systemctl enable nginx
  sudo systemctl start nginx
EOF

# === Deploy App ===
echo "🐳 Deploying Docker app..."
ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" bash <<EOF
  set -e
  cd "$REPO_NAME"
  if [ -f "docker-compose.yml" ]; then
    docker-compose down || true
    docker-compose up -d --build
  else
    docker stop app || true
    docker rm app || true
    docker build -t app .
    docker run -d --name app -p $APP_PORT:$APP_PORT app
  fi
EOF

# === Nginx Config ===
echo "🌐 Configuring Nginx reverse proxy..."
ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" bash <<EOF
  set -e
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
EOF

# === Validation ===
echo "✅ Validating deployment..."
ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" bash <<EOF
  set -e
  echo "Docker status:"
  sudo systemctl is-active docker
  echo "Running containers:"
  docker ps
  echo "Nginx status:"
  sudo systemctl is-active nginx
  echo "Testing app endpoint:"
  curl -s http://localhost | grep -i html || echo "⚠️ App may not be responding"
EOF

echo "🎉 Deployment complete. Visit: http://$SERVER_IP"
