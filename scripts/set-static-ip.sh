#!/bin/sh

# Backup file cũ
cp /etc/network/interfaces /etc/network/interfaces.bak

# Ghi đè cấu hình Static IP
# Lưu ý: Gateway trỏ về IP của Router trong VLAN 99 (172.16.99.1)
cat > /etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address 172.16.99.10
    netmask 255.255.255.0
    gateway 172.16.99.1
    dns-nameservers 8.8.8.8 1.1.1.1
EOF

echo "[OK] Đã cấu hình IP tĩnh: 172.16.99.10"
