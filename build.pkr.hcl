build {
  sources = ["source.proxmox-iso.alpine_docker"]

  # 1. Upload docker-compose
  provisioner "shell" {
    inline = ["mkdir -p /opt/traefik/dynamic_conf"]
  }

  provisioner "file" {
    source      = "files/docker-compose.yml"
    destination = "/opt/traefik/docker-compose.yml"
  }

  provisioner "file" {
    source      = "files/dynamic_conf"
    destination = "/opt/traefik"
  }

  provisioner "file" {
    source      = "scripts/manage-proxy.sh"
    destination = "/usr/local/bin/proxy-ctl"
  }

  provisioner "file" {
    source      = "scripts/setup-stack.sh"
    destination = "/usr/local/bin/setup"
  }

  provisioner "shell" {
    script = "scripts/setup-docker.sh"
  }

  provisioner "shell" {
    script = "scripts/set-static-ip.sh"
  }
}
