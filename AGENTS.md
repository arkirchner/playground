# AGENTS.md

Multi-project playground repo. Primary project: `kvm_cluster/`.

## kvm_cluster — Talos Linux on KVM

Terraform/OpenTofu project provisioning a Talos Linux Kubernetes cluster with Cilium CNI, Gateway API, cert-manager, and Longhorn storage.

### Structure

```
kvm_cluster/
  flake.nix              # Nix dev shell (provides talosctl + tofu)
  .envrc                 # direnv integration
  modules/talos-cluster/ # Shared module: Talos config, Cilium, cert-manager, Longhorn
  environments/local/    # KVM/libvirt deployment (NAT network, local VMs)
  environments/production/ # IONOS Cloud deployment (stub, not yet implemented)
  setup_clients          # Post-apply script: exports kubeconfig + talosconfig
```

### Commands

All Terraform commands run from an environment directory:

```bash
direnv allow                     # activate Nix shell (tofu + talosctl)
cd kvm_cluster/environments/local
tofu init
tofu plan
tofu apply
../setup_clients                 # export kubeconfig (~/.kube/config) and talosconfig (~/.talos/config)
```

Production env: same flow but `cd environments/production` and requires `IONOS_USERNAME`/`IONOS_PASSWORD` env vars.

### Key details

- Uses **OpenTofu** (`tofu`), not Terraform. The Nix flake provides it.
- Local environment depends on **libvirt** (`qemu:///system`). VMs are libvirt domains with a NAT network (`10.0.0.0/24`).
- Talos image is fetched from `factory.talos.dev` and decompressed with `zstd` during apply. Cached in `.talos_image/`.
- CNI is Cilium with kube-proxy replacement. No default CNI (`cni.name = "none"`).
- Gateway API CRDs are fetched from GitHub and applied before Cilium Helm release.
- Local uses self-signed cert-manager issuer; production uses Let's Encrypt ACME with HTTP-01 via Gateway.
- Longhorn uses `/var/mnt/persistent-storage` (a user volume on the worker system disk).
- `setup_clients` hardcodes node IP `10.0.0.10` for `talosctl health` — update if you change `controlplane_ips`.

### Other projects

- `torch/` — Ruby ML experiments (LibTorch bindings), independent flake.
- `web_python_svg/` — Single HTML file, no build system.
