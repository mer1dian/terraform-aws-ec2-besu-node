/*
* AWS Regions = ue1|uw1|uw2|ew1|ec1|an1|an2|as1|as2|se1
* For now, handcode region with AMI pairing 
* Freight Trust 
*/

variable "aws_region" {
  description = "AWS Region for deployment."
}

variable "cert_owner" {
  description = "owner of vault certs"
  default     = "$USER"
}

variable "availability_zones" {
  description = "avail. zones"
  default     = []
}

variable "create_load_balancer" {
  description = "Whether to create a load balancer to load balance RPC requests."
  default     = true
}

variable "use_internal_load_balancer" {
  description = "Whether to use an internal load balancer. Recommended if it only needs to be reachable from the same VPC."
  default     = false
}

variable "public_key_path" {
  description = "The path to the public key that will be used to SSH the instances in this region."
  default     = ""
}

variable "public_key" {
  description = "The public key that will be used to SSH the instances in this region. Will override public_key_path if set."
  default     = ""
}

variable "vault_dns" {
  description = "The dns that vault will be accessible on. Leave as default for a local vault."
  default     = "127.0.0.1"
}

variable "vault_cert_bucket" {
  description = "The name of the S3 bucket containing vault certificates. Leave empty if using a local vault."
  default     = ""
}

variable "vault_port" {
  description = "The port that vault will be accessible on."
  default     = 8200
}

variable "network_id" {
  description = "The network ID of the freight-trust network to join"
  default     = 211
}

variable "node_count" {
  description = "The number of nodes to launch behind the load balancer."
  default     = 1
}

variable "node_volume_size" {
  description = "Disk Size"
  default     = 120
}

variable "force_destroy_s3_bucket" {
  description = "prod=false"
  default     = false
}

variable "rpc_cidrs" {
  description = "List of CIDR ranges to allow access to the RPC port."
  default     = []
}

variable "rpc_security_groups" {
  description = "List of security groups in the same region to allow access to the RPC port."
  default     = []
}

variable "freight-trust_node_ami" {
  description = "AMI ID"
  default     = ""
}

variable "freight-trust_node_instance_type" {
  description = "EC2 might change later on"
  default     = "t2.medium"
}

variable "cert_org_name" {
  description = "The organization to associate with the vault certificates."
  default     = "Freight Trust Network."
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
