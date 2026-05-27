locals {
  talos_image_url    = "https://github.com/siderolabs/talos/releases/download/${var.talos_version}/metal-amd64.raw.xz"
  talos_image_xz     = abspath("${path.module}/.talos/metal-amd64.raw.xz")
  talos_image_raw    = abspath("${path.module}/.talos/metal-amd64.raw")
  talos_image_dir    = abspath("${path.module}/.talos")
}

resource "terraform_data" "talos_image" {
  triggers_replace = [var.talos_version]

  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p "${local.talos_image_dir}"
      if [ ! -f "${local.talos_image_raw}" ]; then
        curl -L -o "${local.talos_image_xz}" "${local.talos_image_url}"
        xz -dk "${local.talos_image_xz}"
      fi
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -rf ${abspath("${path.module}/.talos")}"
  }
}

resource "libvirt_pool" "talos" {
  name = "${var.cluster_name}-pool"
  type = "dir"
  path = abspath("${path.module}/.libvirt-pool")
}

resource "libvirt_network" "talos" {
  name      = "${var.cluster_name}-network"
  mode      = "nat"
  domain    = "${var.cluster_name}.local"
  addresses = ["10.0.0.0/24"]
  autostart = true

  dns {
    enabled = true
  }

  dhcp {
    enabled = true
  }
}

resource "libvirt_volume" "talos_base" {
  name   = "${var.cluster_name}-talos-base"
pool = libvirt_pool.talos.name
  source = local.talos_image_raw

  depends_on = [terraform_data.talos_image]
}

resource "libvirt_volume" "controlplane" {
  count          = var.controlplane_count
  name           = "${var.cluster_name}-cp-${count.index}.qcow2"
  pool           = libvirt_pool.talos.name
  base_volume_id = libvirt_volume.talos_base.id
  size           = var.disk_size
}

resource "libvirt_volume" "worker" {
  count          = var.worker_count
  name           = "${var.cluster_name}-worker-${count.index}.qcow2"
  pool           = libvirt_pool.talos.name
  base_volume_id = libvirt_volume.talos_base.id
  size           = var.disk_size
}

resource "libvirt_domain" "controlplane" {
  count     = var.controlplane_count
  name      = "${var.cluster_name}-cp-${count.index}"
  memory    = var.controlplane_memory
  vcpu      = var.controlplane_vcpu
  autostart = true

  cpu {
    mode = "host-passthrough"
  }

  boot_device {
    dev = ["hd"]
  }

  disk {
    volume_id = libvirt_volume.controlplane[count.index].id
  }

  network_interface {
    network_id     = libvirt_network.talos.id
    addresses      = [var.controlplane_ips[count.index]]
    wait_for_lease = true
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "vnc"
    listen_type = "address"
  }
}

resource "libvirt_domain" "worker" {
  count     = var.worker_count
  name      = "${var.cluster_name}-worker-${count.index}"
  memory    = var.worker_memory
  vcpu      = var.worker_vcpu
  autostart = true

  cpu {
    mode = "host-passthrough"
  }

  boot_device {
    dev = ["hd"]
  }

  disk {
    volume_id = libvirt_volume.worker[count.index].id
  }

  network_interface {
    network_id     = libvirt_network.talos.id
    addresses      = [var.worker_ips[count.index]]
    wait_for_lease = true
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "vnc"
    listen_type = "address"
  }
}
