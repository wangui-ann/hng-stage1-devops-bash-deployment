**#  Dockerized App Deployment Script**
This script automates the setup, deployment, and configuration of a Dockerized application on a remote Linux server.

## Features

- Git repo cloning with PAT authentication
- Remote SSH setup and validation
- Docker + Nginx installation
- Docker container deployment
- Nginx reverse proxy configuration
- Full logging and error handling
- Idempotent and cleanup-safe

## Usage

```bash
chmod +x deploy.sh
./deploy.sh
