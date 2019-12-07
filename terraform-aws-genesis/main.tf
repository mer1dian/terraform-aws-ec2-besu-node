/*
* Freight Trust 
*/
provider "aws" {
  version = "~> 1.5"

  region = "${var.aws_region}"
}

resource "aws_vpc" "freight-trust_node" {
  cidr_block           = "${var.vpc_cidr}"
  enable_dns_hostnames = true
}

Create an internet gateway to give our subnet access to the outside world resource "aws_internet_gateway" "freight-trust_node" {
  vpc_id = "${aws_vpc.freight-trust_node.id}"
}

resource "aws_route" "freight-trust_node" {
  route_table_id         = "${aws_vpc.freight-trust_node.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.freight-trust_node.id}"
}

module "freight-trust_node" {
  source = "modules/freight-trust-node"

  network_id                       = "${var.network_id}"
  public_key_path                  = "${var.public_key_path}"
  public_key                       = "${var.public_key}"
  aws_region                       = "${var.aws_region}"
  availability_zones               = "${var.availability_zones}"
  cert_owner                       = "${var.cert_owner}"
  create_load_balancer             = "${var.create_load_balancer}"
  use_internal_load_balancer       = "${var.use_internal_load_balancer}"
  node_count                       = "${var.node_count}"
  node_volume_size                 = "${var.node_volume_size}"
  force_destroy_s3_bucket          = "${var.force_destroy_s3_bucket}"
  freight-trust_node_instance_type = "${var.freight-trust_node_instance_type}"

  vault_dns         = "${var.vault_dns}"
  vault_cert_bucket = "${var.vault_cert_bucket}"
  vault_port        = "${var.vault_port}"

  cert_org_name            = "${var.cert_org_name}"
  consul_cluster_tag_key   = "${var.consul_cluster_tag_key}"
  consul_cluster_tag_value = "${var.consul_cluster_tag_value}"

  rpc_cidrs           = "${var.rpc_cidrs}"
  rpc_security_groups = "${var.rpc_security_groups}"

  freight-trust_node_ami = "${var.freight-trust_node_ami}"

  aws_vpc = "${aws_vpc.freight-trust_node.id}"

  base_subnet_cidr = "${var.vpc_cidr}"
}
