variable "app_subnet_ids" {
  type = list(string)
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "ecr_image_url" {
  type = string
}

variable "project_name" {
  type = string
}

variable "app_sg_id" {
  type = string
}

variable "instance_profile_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "key_name" {
  type = string
}