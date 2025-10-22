**#  Dockerized App Deployment Script**


**## 📦 Project Features**

- ✅ Single-file deployment (`deploy.sh`)
- 🔐 User input collection (Git repo, PAT, branch, port, SSH placeholders)
- 🛠️ Server setup (Docker, Docker Compose, Nginx, curl, dos2unix)
- 🐳 Docker deployment (build and run or use docker-compose)
- 🌐 Nginx reverse proxy configuration
- 🔒 SSL readiness placeholder
- 🧪 Deployment validation (Docker, Nginx, curl checks)
- 🔁 Idempotency and repo reuse
- 🧹 Cleanup of unused Docker resources
- 📜 Logging to timestamped file

---

## 👤 Author

**Name**: Ann Wangui  
**Public Server IP**: [http://23.23.49.43](http://23.23.49.43)

---

b

To deploy the application, SSH into your EC2 instance, clone this repository, make the script executable, and run it:

```bash
ssh -i ~/your-key.pem ubuntu@23.23.49.43
git clone https://github.com/wangui-ann/devops_stage1_gsxznu21.git
cd devops_stage1_gsxznu21
chmod +x deploy.sh
./deploy.sh

## Usage

```bash
chmod +x deploy.sh
./deploy.sh
