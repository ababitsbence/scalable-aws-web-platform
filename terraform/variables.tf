variable "aws_region" {
  type    = string
  default = "eu-west-3"
}

variable "project_name" {
  type = string
}

variable "ecr_repo_name" {
  type = string
}

variable "admin_ip" {
  type = list(string)
}

variable "db_port" {
  type    = number
  default = 5432
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "min_size" {
  type    = number
  default = 1
}

variable "max_size" {
  type    = number
  default = 3
}

variable "desired_capacity" {
  type    = number
  default = 2
}