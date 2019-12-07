variable "aws_region" {
  description = "AWS region to launch servers."
}

variable "cert_owner" {
  description = "Node Operator."
  default     = "$USER"
}

variable "availability_zones" {
  description = "AWS availability zones to distribute the nodes amongst. Must name at least two. Across AZ"
  default     = []
}

variable "create_load_balancer" {
  description = "we can disable this as besu offers authenticated RPC using cli flags"
  default     = true
}

variable "use_internal_load_balancer" {
  description = "Whether to use an internal load balancer. Recommended if it only needs to be reachable from the same VPC."
  default     = false
}

variable "public_key_path" {
  description = "ssh to instances dir"
  default     = ""
}

variable "public_key" {
  description = "override public_key_path if set"
  default     = ""
}

variable "vault_dns" {
  description = "The dns that vault will be accessible on. Leave as default for a local vault"
  default     = "127.0.0.1"
}

variable "vault_cert_bucket" {
  description = "s3 bucket containing vault certificates. Leave empty if using a local vault."
  default     = ""
}

variable "vault_port" {
  description = "The port that vault will be accessible on."
  default     = 8200
}

variable "chain_id" {
  description = "The Chain_ID of the Freight Trust network to join"
  default     = 211
}

variable "network_id" {
  description = "Reserved for Consoritum / Federated chains, identify as chain_id for main network clique"
  default     = 211
}

variable "node_count" {
  description = "The number of nodes to launch behind the load balancer."
  default     = 1
}

variable "node_volume_size" {
  description = "The size of the storage drive on the node"
  default     = 120
}

variable "force_destroy_s3_bucket" {
  description = "s3 persistance"
  default     = false
}

variable "rpc_cidrs" {
  description = "CIDR ranges for RPC port."
  default     = []
}

variable "rpc_security_groups" {
  description = "sec-groups to allow RPC"
  default     = []
}

variable "freight-trust_node_ami" {
  description = "ID of AMI to use for freight-trust node. If not set, will retrieve the latest version from freight-trust."
  default     = ""
}

variable "freight-trust_node_instance_type" {
  description = "AWS Instance Size"
  default     = "t2.medium"
}

variable "cert_org_name" {
  description = "Root Vault Cert."
  default     = "Freight Trust Network"
}

variable "vpc_cidr" {
  description = "The cidr range to use for the VPC."
  default     = "10.0.0.0/16"
}

variable "consul_cluster_tag_key" {
  description = "consul tag key"
  default     = "freight-trust-node-consul-key"
}

variable "consul_cluster_tag_value" {
  description = "consul tag value"
  default     = "auto-join"
}
