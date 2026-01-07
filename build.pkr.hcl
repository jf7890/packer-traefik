build {
  sources = ["source.proxmox-iso.alpine_docker"]

  # 1. Upload file docker-compose
  provisioner "shell" {
    inline = ["mkdir -p /opt/guacamole"]
  }

  provisioner "file" {
    source      = "files/docker-compose.yml"
    destination = "/opt/guacamole/docker-compose.yml"
  }

  provisioner "shell" {
    script = "scripts/setup-docker.sh"
  }

  provisioner "shell" {
    script = "scripts/set-static-ip.sh"
  }
}
