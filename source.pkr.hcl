# Calculate the actual value for cloudinit_storage_pool
locals {
  # If cloudinit_storage_pool is empty, use vm_storage_pool.
  cloudinit_storage = var.cloudinit_storage_pool != "" ? var.cloudinit_storage_pool : var.vm_storage_pool
}

source "proxmox-iso" "alpine_docker" {
  # Connect Proxmox
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
    iso_storage_pool = var.iso_storage_pool
    iso_download_pve = true
    unmount          = true
  }

  # Hardware (Up RAM/Disk for Docker)
  vm_name              = var.vm_name
  template_name        = "tpl-guacamole"
  template_description = "Alpine Docker Host (Traefik + Guacamole)"
  memory               = 2048   # 2GB RAM
  cores                = 2
  sockets              = 1
  scsi_controller      = "virtio-scsi-single"
  qemu_agent           = true
  
  # Disk 10GB
  disks {
    type         = "scsi"
    disk_size    = "10G"
    storage_pool = var.vm_storage_pool
    format       = "raw"
  }

  # Network (just use LAN bridge for Guacamole)
  network_adapters {
    model    = "virtio"
    bridge   = var.bridge_lan
    vlan_tag = var.vlan_tag
    firewall = false
  }

  # HTTP Server serves Answer File
  http_content = {
    "/answers" = templatefile("http/answers.pkrtpl.hcl", {
      ssh_public_key = var.ssh_public_key
    })
  }

  # Boot Command
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
  cloud_init_storage_pool = local.cloudinit_storage
}
