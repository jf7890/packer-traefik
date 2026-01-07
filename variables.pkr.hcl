variable "proxmox_url" { type = string }
variable "proxmox_username" { type = string }
variable "proxmox_token" { type = string; sensitive = true }
variable "proxmox_node" { type = string }
variable "ssh_public_key" { type = string }
variable "ssh_private_key_file" { type = string }
variable "vm_name" {
  type    = string
  default = "guacamole-mgmt"
}
