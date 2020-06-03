##################################################################################
# VARIABLES
##################################################################################

variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "private_key_path" {}
variable "key_name" {}
variable "region" {
  default = "eu-west-1"
}
variable network_address_space {
  type = map(string)
}
variable "instance_size" {
  type = map(string)
}
variable "web_subnet_count" {
  type = map(number)
}
variable "app_subnet_count" {
  type = map(number)
}
variable "web_instance_count" {
  type = map(number)
}
variable "app_instance_count" {
  type = map(number)
}
variable "db_instance_count" {
  type = map(number)
}

##################################################################################
# LOCALS
##################################################################################

locals {
  env_name = lower(terraform.workspace)

  common_tags = {
    Environment = local.env_name
  }

  total_subnet_count = var.app_subnet_count[terraform.workspace] + var.web_subnet_count[terraform.workspace]
}