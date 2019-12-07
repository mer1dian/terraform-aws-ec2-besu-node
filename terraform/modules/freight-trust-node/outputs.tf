output "freight-trust_node_dns" {
  value = "${element(coalescelist(aws_lb.freight-trust_node.*.dns_name, data.aws_instance.freight-trust_node.*.public_dns), 0)}"
}

output "freight-trust_lb_zone_id" {
  value = "${element(coalescelist(aws_lb.freight-trust_node.*.zone_id, list("")), 0)}"
}

output "freight-trust_node_ssh_dns" {
  value = "${data.aws_instance.freight-trust_node.*.public_dns}"
}

/*
 * @dev Change RPC Port below 
 * @param value = rpc-port
 * @note 30303, 8545, 8547 
 */
output "freight-trust_node_rpc_port" {
  value = "30303"
}

output "freight-trust_node_iam_role" {
  value = "${aws_iam_role.freight-trust_node.name}"
}

output "freight-trust_node_security_group_id" {
  value = "${aws_security_group.freight-trust_node.id}"
}

output "freight-trust_load_balancer_security_group_id" {
  value = "${element(coalescelist(aws_security_group.freight-trust_load_balancer.*.id, list("")), 0)}"
}
