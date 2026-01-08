# PROXMOX CONNECTION
variable "proxmox_url" {
  description = "Proxmox API endpoint URL"
  type        = string
  default     = "https://192.168.1.100:8006/api2/json"
}

variable "proxmox_username" {
  description = "API username (e.g., user@pam!token)"
  type        = string
  default     = "root@pam"
}

variable "proxmox_token" {
  description = "API token in format token_id=token_secret"
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "Target Proxmox node name"
  type        = string
  default     = "pve"
}

# STORAGE (read from ENV: PKR_VAR_xxx)
variable "iso_storage_pool" {
  description = "Storage pool for ISO images and templates"
  type        = string
  default     = "local"
}

variable "vm_storage_pool" {
  description = "Storage pool for VM disks"
  type        = string
  default     = "local-lvm"
}

variable "cloudinit_storage_pool" {
  description = "Storage pool for Cloud-init drive (defaults to vm_storage_pool)"
  type        = string
  default     = ""
}

# SSH KEY (read from ENV: PKR_VAR_xxx)
variable "ssh_public_key" {
  description = "SSH public key content for VM provisioning"
  type        = string
}

variable "ssh_private_key_file" {
  description = "Path to SSH private key file"
  type        = string
  default     = "~/.ssh/id_ed25519"
}

# NETWORK (read from ENV: PKR_VAR_xxx)
variable "bridge_lan" {
  description = "LAN bridge (SDN Vnet) for internal lab network"
  type        = string
  default     = "nonet"
}

variable "vlan_tag" {
  description = "VLAN tag for network adapter"
  type        = string
  default     = "99"
}

# VM CONFIG
variable "vm_name" {
  description = "Name of the VM during build"
  type        = string
  default     = "guacamole-mgmt"
}
