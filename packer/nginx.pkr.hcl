# Packer configuration for building custom Nginx Docker image
# This template creates a Docker image with Nginx and a custom index.html

packer {
  required_plugins {
    docker = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/docker"
    }
  }
}

# Source image configuration
source "docker" "nginx" {
  image  = "nginx:alpine"
  commit = true
  changes = [
    "EXPOSE 80",
    "CMD [\"nginx\", \"-g\", \"daemon off;\"]"
  ]
}

# Build configuration
build {
  name    = "custom-nginx"
  sources = ["source.docker.nginx"]

  # Copy the custom index.html to Nginx's default location
  provisioner "file" {
    source      = "../index.html"
    destination = "/usr/share/nginx/html/index.html"
  }

  # Tag the image for K3d import
  post-processor "docker-tag" {
    repository = "custom-nginx"
    tags       = ["latest"]
  }
}
