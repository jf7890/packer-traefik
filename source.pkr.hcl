source "proxmox-iso" "alpine_docker" {
  # Kết nối Proxmox
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  token                    = var.proxmox_token
  node                     = var.proxmox_node
  insecure_skip_tls_verify = true

  # Boot ISO (Alpine 3.23)
  boot_iso {
    type             = "scsi"
    iso_url          = "https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86_64/alpine-virt-3.23.2-x86_64.iso"
    iso_checksum     = "file:https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86_64/alpine-virt-3.23.2-x86_64.iso.sha256"
    iso_storage_pool = "local"
    iso_download_pve = false
    unmount          = true
  }

  # Hardware (Tăng RAM/Disk cho Docker)
  vm_name         = var.vm_name
  template_name   = "tpl-guacamole"
  template_description = "Alpine Docker Host (Traefik + Guacamole)"
  memory          = 2048   # 2GB RAM
  cores           = 2
  sockets         = 1
  scsi_controller = "virtio-scsi-single"
  qemu_agent      = true
  
  # Disk 10GB
  disks {
    type         = "scsi"
    disk_size    = "10G"
    storage_pool = "local-lvm"
    format       = "raw"
  }

  network_adapters {
    model     = "virtio"
    bridge    = var.bridge_lan
    vlan_tag  = var.vlan_tag
    firewall  = false
  }

  # HTTP Server phục vụ Answer File
  http_content = {
    "/answers" = templatefile("http/answers.pkrtpl.hcl", {
      ssh_public_key = var.ssh_public_key
    })
  }

  # Boot Command (Giống hệt Router)
  boot_wait = "10s"
  boot_command = [
    "<enter><wait>",
    "root<enter><wait>",
    "ifconfig eth0 up && udhcpc -i eth0<enter><wait5>",
    "wget -O /tmp/answers http://{{ .HTTPIP }}:{{ .HTTPPort }}/answers<enter><wait>",

    "ERASE_DISKS=/dev/sda setup-alpine -e -f /tmp/answers && mount /dev/sda3 /mnt && apk add --root /mnt qemu-guest-agent && chroot /mnt rc-update add qemu-guest-agent default && reboot<enter>"
  ]

  # SSH
  ssh_username         = "root"
  ssh_private_key_file = var.ssh_private_key_file
  ssh_timeout          = "20m"

  # Cloud-init
  cloud_init              = true
  cloud_init_storage_pool = "local-lvm"
}
