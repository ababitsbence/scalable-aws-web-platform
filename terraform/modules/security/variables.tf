variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "admin_ip" {
  type = list(string)
}

variable "db_port" {
  type    = number
  default = 5432
}