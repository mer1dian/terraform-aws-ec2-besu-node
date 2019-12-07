provider "aws" {
  version = "~> 1.5"

  region = "${var.aws_region}"
}

provider "template" {
  version = "~> 1.0"
}

provider "tls" {
  version = "~> 1.1"
}

provider "local" {
  version = "~> 1.1"
}

module "cert_tool" {
  source = "../cert-tool"

  ca_public_key_file_path = "${path.module}/certs/ca.crt.pem"
  public_key_file_path    = "${path.module}/certs/vault.crt.pem"
  private_key_file_path   = "${path.module}/certs/vault.key.pem"
  owner                   = "${var.cert_owner}"
  organization_name       = "${var.cert_org_name}"
  ca_common_name          = "freight-trust-node-vault cert authority"
  common_name             = "freight-trust-node cert network"
  dns_names               = ["localhost"]
  ip_addresses            = ["127.0.0.1"]
  validity_period_hours   = 8760
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "freight-trust_node" {
  count = "${max(2, min(var.node_count, length(var.availability_zones) == 0 ? length(data.aws_availability_zones.available.names) : length(var.availability_zones)))}"

  vpc_id                  = "${var.aws_vpc}"
  availability_zone       = "${length(var.availability_zones) != 0 ? element(concat(var.availability_zones, list("")), count.index) : element(data.aws_availability_zones.available.names, count.index)}"
  cidr_block              = "${cidrsubnet(cidrsubnet(var.base_subnet_cidr, 2, 0), 4, count.index)}"
  map_public_ip_on_launch = true
}

data "local_file" "public_key" {
  count = "${var.public_key == "" ? 1 : 0}"

  filename = "${var.public_key_path}"
}

resource "aws_key_pair" "auth" {
  key_name_prefix = "freight-trust-node-net-${var.network_id}-"
  public_key      = "${var.public_key == "" ? join("", data.local_file.public_key.*.content) : var.public_key}"
}

resource "aws_s3_bucket" "vault_storage" {
  bucket_prefix = "freight-trust-node-"
  force_destroy = "${var.force_destroy_s3_bucket}"
}

resource "aws_iam_role" "freight-trust_node" {
  name_prefix = "freight-trust-node-net-${var.network_id}-"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Action": "sts:AssumeRole",
    "Principal": {
      "Service": "ec2.amazonaws.com"
    },
    "Effect": "Allow",
    "Sid": ""
  }]
}
EOF
}

resource "aws_iam_policy" "allow_aws_auth" {
  name_prefix = "freight-trust-aws-auth-net-${var.network_id}-"
  description = "Auth into s3 via vault"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "ec2:DescribeInstances",
      "iam:GetInstanceProfile",
      "iam:GetUser",
      "iam:GetRole"
    ],
    "Resource": "*"
  }]
}
EOF
}

resource "aws_iam_policy" "allow_s3_bucket" {
  name_prefix = "freight-trust-s3-bucket-net-${var.network_id}-"
  description = "Auth into s3 via vault"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["s3:*"],
    "Resource": [
      "${aws_s3_bucket.vault_storage.arn}",
      "${aws_s3_bucket.vault_storage.arn}/*"
    ]
  }]
}
EOF
}

resource "aws_iam_role_policy_attachment" "allow_aws_auth" {
  role       = "${aws_iam_role.freight-trust_node.name}"
  policy_arn = "${aws_iam_policy.allow_aws_auth.arn}"
}

resource "aws_iam_role_policy_attachment" "allow_s3_bucket" {
  role       = "${aws_iam_role.freight-trust_node.name}"
  policy_arn = "${aws_iam_policy.allow_s3_bucket.arn}"
}

module "consul_iam_policies_servers" {
  source = "github.com/hashicorp/terraform-aws-consul.git//modules/consul-iam-policies?ref=v0.1.3"

  iam_role_id = "${aws_iam_role.freight-trust_node.name}"
}

resource "aws_iam_instance_profile" "freight-trust_node" {
  name = "${aws_iam_role.freight-trust_node.name}"
  role = "${aws_iam_role.freight-trust_node.name}"
}

resource "aws_security_group" "freight-trust_node" {
  name        = "freight-trust_node"
  description = "Used for Freight Trust Network Node"
  vpc_id      = "${var.aws_vpc}"
}

/*
TODO: Replace with Bastion configuration
*
*/
resource "aws_security_group_rule" "freight-trust_node_ssh" {
  security_group_id = "${aws_security_group.freight-trust_node.id}"
  type              = "ingress"

  from_port = 22
  to_port   = 22
  protocol  = "tcp"

  cidr_blocks = ["0.0.0.0/0"]
}

/* 
TODO: reserved for proper integration for federated deployment

resource "aws_security_group_rule" "freight-trust_node_kepler" {
  security_group_id = "${aws_security_group.freight-trust_node.id}"
  type              = "ingress"

  from_port = 
  to_port   = 9000
  protocol  = "tcp"

  cidr_blocks = ["0.0.0.0/0"]
}
*/
resource "aws_security_group_rule" "freight-trust_node_besu" {
  security_group_id = "${aws_security_group.freight-trust_node.id}"
  type              = "ingress"

  from_port = 8545
  to_port   = 8545
  protocol  = "tcp"

  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "besu_udp" {
  security_group_id = "${aws_security_group.freight-trust_node.id}"
  type              = "ingress"

  from_port = 8545
  to_port   = 8545
  protocol  = "udp"

  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "freight-trust_node_rpc_self" {
  security_group_id = "${aws_security_group.freight-trust_node.id}"
  type              = "ingress"

  from_port = 22000
  to_port   = 22000
  protocol  = "tcp"

  self = true
}

resource "aws_security_group_rule" "freight-trust_node_rpc_cidrs" {
  count = "${var.create_load_balancer ? 0 : length(var.rpc_cidrs) == 0 ? 0 : 1}"

  security_group_id = "${aws_security_group.freight-trust_node.id}"
  type              = "ingress"

  from_port = 22000
  to_port   = 22000
  protocol  = "tcp"

  cidr_blocks = "${var.rpc_cidrs}"
}

resource "aws_security_group_rule" "freight-trust_node_rpc_security_groups" {
  count = "${var.create_load_balancer ? 0 : var.num_rpc_security_groups}"

  security_group_id = "${aws_security_group.freight-trust_node.id}"
  type              = "ingress"

  from_port = 22000
  to_port   = 22000
  protocol  = "tcp"

  source_security_group_id = "${element(var.rpc_security_groups, count.index)}"
}

resource "aws_security_group_rule" "freight-trust_node_rpc_lb" {
  count = "${var.create_load_balancer ? 1 : 0}"

  security_group_id = "${aws_security_group.freight-trust_node.id}"
  type              = "ingress"

  from_port = 22000
  to_port   = 22000
  protocol  = "tcp"

  source_security_group_id = "${aws_security_group.freight-trust_load_balancer.id}"
}

resource "aws_security_group_rule" "freight-trust_node_egress" {
  security_group_id = "${aws_security_group.freight-trust_node.id}"
  type              = "egress"

  from_port = 0
  to_port   = 0
  protocol  = "-1"

  cidr_blocks = ["0.0.0.0/0"]
}

/*
* Opeartor Node Group
*/
resource "aws_autoscaling_group" "freight-trust_node" {
  count = "${var.node_count}"

  name_prefix = "freight-trust-node-${count.index}-net-${var.network_id}-"

  launch_configuration = "${element(aws_launch_configuration.freight-trust_node.*.name, count.index)}"

  target_group_arns = ["${element(coalescelist(aws_lb_target_group.freight-trust_node_rpc.*.arn, list("")), 0)}"]

  min_size         = 1
  max_size         = 1
  desired_capacity = 1

  health_check_grace_period = 300
  health_check_type         = "EC2"

  vpc_zone_identifier = ["${element(aws_subnet.freight-trust_node.*.id, count.index)}"]
}

resource "aws_launch_configuration" "freight-trust_node" {
  count = "${var.node_count}"

  name_prefix = "freight-trust-node-${count.index}-net-${var.network_id}-"

  image_id      = "${var.freight-trust_node_ami == "" ? element(coalescelist(data.aws_ami.freight-trust_node.*.id, list("")), 0) : var.freight-trust_node_ami}"
  instance_type = "${var.freight-trust_node_instance_type}"
  user_data     = "${element(data.template_file.user_data_freight-trust_node.*.rendered, count.index)}"

  key_name = "${aws_key_pair.auth.id}"

  iam_instance_profile = "${aws_iam_instance_profile.freight-trust_node.name}"
  security_groups      = ["${aws_security_group.freight-trust_node.id}"]

  root_block_device {
    volume_size = "${var.node_volume_size}"
  }
}

data "template_file" "user_data_freight-trust_node" {
  count = "${var.node_count}"

  template = "${file("${path.module}/user-data/user-data-freight-trust-node.sh")}"

  vars {
    aws_region     = "${var.aws_region}"
    network_id     = "${var.network_id}"
    s3_bucket_name = "${aws_s3_bucket.vault_storage.id}"
    iam_role_name  = "${aws_iam_role.freight-trust_node.name}"

    vault_dns         = "${var.vault_dns}"
    vault_port        = "${var.vault_port}"
    vault_cert_bucket = "${var.vault_cert_bucket}"

    vault_ca_public_key = "${module.cert_tool.ca_public_key}"
    vault_public_key    = "${module.cert_tool.public_key}"
    vault_private_key   = "${module.cert_tool.private_key}"

    consul_cluster_tag_key   = "${var.consul_cluster_tag_key}"
    consul_cluster_tag_value = "${var.consul_cluster_tag_value}"

    node_index = "${count.index}"
  }
}

data "aws_ami" "freight-trust_node" {
  count = "${var.freight-trust_node_ami == "" ? 1 : 0}"

  most_recent = true
  owners      = ["0x000000"]

  filter {
    name   = "name"
    values = ["freight-trust-node-*"]
  }
}

data "aws_instance" "freight-trust_node" {
  count = "${var.node_count}"

  filter {
    name   = "tag:aws:autoscaling:groupName"
    values = ["${element(aws_autoscaling_group.freight-trust_node.*.name, count.index)}"]
  }
}
