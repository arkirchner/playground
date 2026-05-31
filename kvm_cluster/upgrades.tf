locals {
  talos_config     = abspath("${path.module}/.talos/talosconfig")
  talos_config_dir = abspath("${path.module}/.talos")
}

# Write talosconfig to a local file for talosctl commands
resource "terraform_data" "talosconfig" {
  triggers_replace = [
    sha256(data.talos_client_configuration.this.talos_config)
  ]

  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p "${local.talos_config_dir}"
      cat > "${local.talos_config}" << 'EOF'
${data.talos_client_configuration.this.talos_config}
EOF
      chmod 700 "${local.talos_config_dir}"
      chmod 600 "${local.talos_config}"
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -Rf ${path.module}/.talos"
  }
}

# Upgrade control plane nodes sequentially
resource "terraform_data" "upgrade_controlplane" {
  triggers_replace = [
    var.talos_version
  ]

  depends_on = [
    terraform_data.talosconfig,
    talos_machine_configuration_apply.controlplane
  ]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      TALOSCONFIG="${local.talos_config}"
      IMAGE="${local.installer_image}"
      
      for node in ${join(" ", var.controlplane_ips)}; do
        echo "Upgrading control plane node: $node"
        talosctl upgrade \
          --nodes "$node" \
          --image "$IMAGE" \
          --talosconfig "$TALOSCONFIG"
      done
    EOT
  }
}

# Upgrade worker nodes sequentially (after control planes)
resource "terraform_data" "upgrade_workers" {
  triggers_replace = [
    var.talos_version
  ]

  depends_on = [
    terraform_data.upgrade_controlplane,
    talos_machine_configuration_apply.worker
  ]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      TALOSCONFIG="${local.talos_config}"
      IMAGE="${local.installer_image}"
      
      for node in ${join(" ", var.worker_ips)}; do
        echo "Upgrading worker node: $node"
        talosctl upgrade \
          --nodes "$node" \
          --image "$IMAGE" \
          --talosconfig "$TALOSCONFIG"
      done
    EOT
  }
}
