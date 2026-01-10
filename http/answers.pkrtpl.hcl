KEYMAPOPTS="us us"
HOSTNAMEOPTS="-n guacamole"
# Networking: eth0 DHCP (để Packer SSH vào)
INTERFACESOPTS="auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
"

DNSOPTS="-d 8.8.8.8"
TIMEZONEOPTS="-z Asia/Ho_Chi_Minh"
PROXYOPTS="none"

APKREPOSOPTS="-1 -c"
USEROPTS="none"

SSHDOPTS="openssh"
ROOTSSHKEY="${ssh_public_key}"

# Disk & NTP
NTPOPTS="-c chrony"
DISKOPTS="-m sys /dev/sda"
LBUOPTS="none"
APKCACHEOPTS="/var/cache/apk"
