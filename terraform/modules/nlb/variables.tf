variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "app_server_ids" {
  type = list(string)
}

variable "app_sg_id" {
  type = string
}

variable "nlb_sg_id" {
  type = string
}