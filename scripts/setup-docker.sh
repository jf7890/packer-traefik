#!/bin/sh

# 1. Cài đặt Docker và Compose
echo "[+] Installing Docker..."
apk update
apk add docker docker-cli-compose bash

# 2. Bật Docker service
rc-update add docker default
service docker start

# --- FIX: ĐỢI DOCKER SẴN SÀNG ---
echo "[+] Waiting for Docker daemon..."
# Vòng lặp đợi file socket xuất hiện (tối đa 30s)
i=0
while [ ! -S /var/run/docker.sock ] && [ $i -lt 30 ]; do
    echo "."
    sleep 1
    i=$((i+1))
done
# Chờ thêm 2s cho chắc ăn
sleep 2 
echo "[+] Docker is ready!"

# 3. Chuẩn bị thư mục project
mkdir -p /opt/guacamole/init

# 4. Tạo init script cho Database Guacamole
echo "[+] Generating Guacamole DB Schema..."

# Thử pull trước để đảm bảo mạng ok
docker pull guacamole/guacamole:latest

# Xuất schema (quan trọng nhất)
docker run --rm guacamole/guacamole:latest /opt/guacamole/bin/initdb.sh --postgres > /opt/guacamole/init/initdb.sql

# Kiểm tra xem file có dữ liệu không
if [ -s /opt/guacamole/init/initdb.sql ]; then
    echo "[OK] Schema created successfully."
else
    echo "[ERROR] Schema generation FAILED."
    exit 1
fi

# 5. Cấu hình tự động chạy Docker Compose
echo "[+] Configuring Auto-start..."
cat > /etc/local.d/docker-compose.start <<EOF
#!/bin/sh
# Đợi docker sẵn sàng khi boot máy thật
while [ ! -S /var/run/docker.sock ]; do sleep 1; done
cd /opt/guacamole
docker compose up -d
EOF

chmod +x /etc/local.d/docker-compose.start
rc-update add local default

# 6. Dọn dẹp
echo "[+] Cleanup..."
# Stop docker để packer shutdown nhanh hơn
service docker stop
rm -rf /var/cache/apk/*
