#!/bin/bash
set -e

dnf update -y
dnf install -y docker

systemctl enable docker
systemctl start docker

mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

aws ecr get-login-password --region ${aws_region} | docker login --username AWS --password-stdin ${ecr_registry}

mkdir -p /opt/app

cat > /opt/app/docker-compose.yml << 'COMPOSE_EOF'
services:
  app1:
    image: ${ecr_image_url}
    restart: always
    expose:
      - "3000"
  app2:
    image: ${ecr_image_url}
    restart: always
    expose:
      - "3000"
  nginx:
    image: nginx:alpine
    restart: always
    ports:
      - "80:80"
    volumes:
      - /opt/app/nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - app1
      - app2
COMPOSE_EOF

cat > /opt/app/nginx.conf << 'NGINX_EOF'
events {
    worker_connections 1024;
}

http {
    upstream backend {
        server app1:3000;
        server app2:3000;
    }

    server {
        listen 80;

        location /health {
            return 200 'OK';
            add_header Content-Type text/plain;
        }

        location / {
            proxy_pass http://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
}
NGINX_EOF

cd /opt/app
docker compose up -d