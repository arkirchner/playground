# TODO: Add Ionos Cloud VPS provisioning
#
# Example resources:
#   resource "ionoscloud_server" "controlplane" { ... }
#   resource "ionoscloud_server" "worker" { ... }
#
# After provisioning, pass node_dependency to the module:
#   node_dependency = [ionoscloud_server.controlplane, ionoscloud_server.worker]
