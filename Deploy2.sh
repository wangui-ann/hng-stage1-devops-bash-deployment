# #!/bin/sh

# set -e
# set -u

# # === Globals ===
# LOG_FILE="deploy_$(date +%Y%m%d_%H%M%S).log"
# REPO_DIR=""
# CLEANUP=false

# # === Logging ===
# log() {
#     echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
# }

# trap 'log "ERROR: Script failed at line $LINENO"; exit 1' ERR

# # === Input Collection ===
# read_input() {
#     echo "🔧 Collecting deployment parameters..."

#     read -r -p "Git Repository URL: " REPO_URL
#     read -r -p "Personal Access Token (PAT): " PAT
#     read -r -p "Branch name [default: main]: " BRANCH
#     BRANCH=${BRANCH:-main}
#     read -r -p "Remote SSH Username: " SSH_USER
#     read -r -p "Remote Server IP: " SERVER_IP
#     read -r -p "SSH Key Path: " SSH_KEY
#     read -r -p "Application internal port (e.g., 3000): " APP_PORT

#     if [ "$#" -gt 0 ] && [ "$1" = "--cleanup" ]; then
#         CLEANUP=true
#     fi
# }

# # === Clone Repository ===
# clone_repo() {
#     log "📦 Cloning repository..."
#     REPO_NAME=$(basename "$REPO_URL" .git)
#     REPO_DIR="$REPO_NAME"

#     if [ -d "$REPO_DIR" ]; then
#         log "Repo exists. Pulling latest changes..."
#         cd "$REPO_DIR" && git pull origin "$BRANCH"
#     else
#         git clone https://"$PAT"@"${REPO_URL#https://}" --branch "$BRANCH"
#         cd "$REPO_DIR"
#     fi

#     if [ -f "Dockerfile" ] || [ -f "docker-compose.yml" ]; then
#         log "✅ Docker configuration found."
#     else
#         log "❌ No Dockerfile or docker-compose.yml found. Exiting."
#         exit 2
#     fi
# }

# # === SSH Connectivity Check ===
# check_ssh() {
#     log "🔐 Checking SSH connectivity..."
#     ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$SSH_USER@$SERVER_IP" "echo SSH connection successful" || {
#         log "❌ SSH connection failed."
#         exit 3
#     }
# }

# # === Remote Setup ===
# prepare_remote() {
#     log "🧰 Preparing remote environment..."
#     ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" <<EOF
#         set -e
#         sudo apt update -y
#         sudo apt install -y docker.io docker-compose nginx curl
#         sudo usermod -aG docker \$USER
#         sudo systemctl enable docker nginx
#         sudo systemctl start docker nginx
#         docker --version
#         docker-compose --version
#         nginx -v
# EOF
# }

# # === Deploy Application ===
# deploy_app() {
#     log "🚀 Deploying application..."
#     ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" "mkdir -p ~/app"

#     # rsync -avz -e "ssh -i $SSH_KEY" "$REPO_DIR/" "$SSH_USER@$SERVER_IP:~/app"
#     rsync -avz --exclude='.git' -e "ssh -i $SSH_KEY" ./ "$SSH_USER@$SERVER_IP:/home/ubuntu/app"






#     ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" <<EOF
#         cd ~/app
#         if [ -f "docker-compose.yml" ]; then
#             docker-compose down || true
#             docker-compose up -d --build
#         else
#             docker stop app || true
#             docker rm app || true
#             docker build -t app .
#             docker run -d --name app -p $APP_PORT:$APP_PORT app
#         fi
#         sleep 5
#         docker ps
# EOF
# }

# # === Configure Nginx ===
# configure_nginx() {
#     log "🌐 Configuring Nginx reverse proxy..."
#     ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" <<EOF
#         sudo tee /etc/nginx/sites-available/app.conf > /dev/null <<NGINX
# server {
#     listen 80;
#     location / {
#         proxy_pass http://localhost:$APP_PORT;
#         proxy_set_header Host \$host;
#         proxy_set_header X-Real-IP \$remote_addr;
#     }
# }
# NGINX
#         sudo ln -sf /etc/nginx/sites-available/app.conf /etc/nginx/sites-enabled/app.conf
#         sudo nginx -t && sudo systemctl reload nginx
# EOF
# }

# # === Validate Deployment ===
# validate_deployment() {
#     log "🔍 Validating deployment..."
#     ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" <<EOF
#         docker ps | grep app || exit 4
#         curl -s http://localhost | grep -i html || echo "App not responding"
# EOF
#     curl -s "http://$SERVER_IP" | grep -i html && log "✅ Deployment successful" || log "⚠️ App may not be responding"
# }

# # === Cleanup ===
# cleanup() {
#     if [ "$CLEANUP" = true ]; then
#         log "🧹 Performing cleanup..."
#         ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" <<EOF
#             docker-compose down || true
#             docker stop app || true
#             docker rm app || true
#             sudo rm -rf ~/app
#             sudo rm -f /etc/nginx/sites-enabled/app.conf /etc/nginx/sites-available/app.conf
#             sudo systemctl reload nginx
# EOF
#         log "✅ Cleanup complete."
#         exit 0
#     fi
# }

# # === Main Execution ===
# main() {
#     read_input "$@"
#     clone_repo
#     check_ssh
#     prepare_remote
#     deploy_app
#     configure_nginx
#     validate_deployment
#     cleanup
#     log "🎉 All steps completed."
# }

# main "$@"
