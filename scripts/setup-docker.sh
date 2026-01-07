#!/bin/sh

# 1. Cài đặt Docker và Compose
echo "[+] Installing Docker..."
apk update
apk add docker docker-cli-compose bash

# 2. Bật Docker service
rc-update add docker default
service docker start

# 3. Chuẩn bị thư mục project
mkdir -p /opt/guacamole/init

# (Lưu ý: file docker-compose.yml sẽ được Packer upload vào /opt/guacamole sau)

# 4. Tạo init script cho Database Guacamole
# Chúng ta cần image chạy 1 lần để dump file SQL ra
echo "[+] Generating Guacamole DB Schema..."
# Pull image trước để lấy script
docker pull guacamole/guacamole
docker run --rm guacamole/guacamole /opt/guacamole/bin/initdb.sh --postgres > /opt/guacamole/init/initdb.sql

# 5. Cấu hình tự động chạy Docker Compose khi boot (dùng local.d của Alpine)
echo "[+] Configuring Auto-start..."
cat > /etc/local.d/docker-compose.start <<EOF
#!/bin/sh
cd /opt/guacamole
docker compose up -d
EOF

chmod +x /etc/local.d/docker-compose.start
rc-update add local default

# 6. Dọn dẹp
echo "[+] Cleanup..."
rm -rf /var/cache/apk/*
