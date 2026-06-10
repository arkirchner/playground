locals {
  talos_image_url = "https://factory.talos.dev/image/${local.schematic_id}/${var.talos_version}/metal-amd64.raw.zst"
  talos_image_zst = abspath("${path.module}/.talos_image/metal-amd64.raw.zst")
  talos_image_raw = abspath("${path.module}/.talos_image/metal-amd64.raw")
  talos_image_dir = abspath("${path.module}/.talos_image")
}

resource "terraform_data" "talos_image" {
  triggers_replace = [var.talos_version, local.schematic_id]

  provisioner "local-exec" {
    command = <<-EOT
      rm -rf "${local.talos_image_dir}"
      mkdir -p "${local.talos_image_dir}"
      curl -L -o "${local.talos_image_zst}" "${local.talos_image_url}"
      zstd -dk "${local.talos_image_zst}"
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -rf ${path.module}/.talos_image"
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
  pool   = libvirt_pool.talos.name
  source = local.talos_image_raw

  depends_on = [terraform_data.talos_image]
}

resource "libvirt_volume" "controlplane" {
  count          = length(var.controlplane_ips)
  name           = "${var.cluster_name}-cp-${count.index}.qcow2"
  pool           = libvirt_pool.talos.name
  base_volume_id = libvirt_volume.talos_base.id
  size           = 32212254720
}

resource "libvirt_volume" "worker" {
  count          = length(var.worker_ips)
  name           = "${var.cluster_name}-worker-${count.index}.qcow2"
  pool           = libvirt_pool.talos.name
  base_volume_id = libvirt_volume.talos_base.id
  size           = 32212254720
}

resource "libvirt_domain" "controlplane" {
  count     = length(var.controlplane_ips)
  name      = "${var.cluster_name}-cp-${count.index}"
  memory    = 2048
  vcpu      = 2
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
  count     = length(var.worker_ips)
  name      = "${var.cluster_name}-worker-${count.index}"
  memory    = 2048
  vcpu      = 2
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
