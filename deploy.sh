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
if [[ -z "$REPO_URL" || -z "$PAT" || -z "$SSH_USER" || -z "$SERVER_IP" || -z "$SSH_KEY" || -z "$APP_PORT" ]]; then
  echo "❌ All fields are required. Please provide valid inputs."
  exit 1
fi

# === SSH Connectivity Check ===
echo "🔐 Checking SSH connectivity..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@$SERVER_IP" "echo SSH OK" || {
  echo "❌ SSH connection failed"
  exit 1
}

# === Git Operations ===
REPO_NAME=$(basename "$REPO_URL" .git)
echo "📦 Cloning repository..."
ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" bash <<EOF
  set -e
  if [ -d "$REPO_NAME" ]; then
    cd "$REPO_NAME"
    git fetch origin
    git checkout "$BRANCH"
    git pull origin "$BRANCH"
  else
    git clone -b "$BRANCH" https://$PAT@${REPO_URL#https://} "$REPO_NAME"
  fi
EOF

# === Server Preparation ===
echo "🛠️ Preparing remote server..."
ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" bash <<EOF
  set -e
  sudo apt
