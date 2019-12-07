output "freight-trust_node_dns" {
  value = "${module.freight-trust_node.freight-trust_node_dns}"
}

output "freight-trust_lb_zone_id" {
  value = "${module.freight-trust_node.freight-trust_lb_zone_id}"
}

output "freight-trust_node_ssh_dns" {
  value = "${module.freight-trust_node.freight-trust_node_ssh_dns}"
}

output "freight-trust_node_rpc_port" {
  value = "${module.freight-trust_node.freight-trust_node_rpc_port}"
}

output "freight-trust_node_iam_role" {
  value = "${module.freight-trust_node.freight-trust_node_iam_role}"
}
