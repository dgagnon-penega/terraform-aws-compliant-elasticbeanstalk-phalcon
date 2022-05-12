variable "aws_region" {
  type = string
}
variable "env_version" {
  type = string
}
variable "env_project" {
  type = string
}
variable "env_client" {
  type = string
}
variable "zone_id" {
  type = string
}
variable "admin_ips" {
  type = list(any)
}
variable "notif_email" {
  type = string
}
variable "app_name" {
  type = string
  default = "Backend"
}
variable "domain_name" {
  type = string
}
variable "xray_enabled" {
  type = bool
  default = false
}

variable "asg_min_size" {
  type        = number
  description = "minSize for the cluster"
  default     = 1
  validation {
    condition     = var.asg_min_size < 3
    error_message = "Less than 3 please."
  }
}

variable "asg_max_size" {
  type        = number
  description = "maxSize for the cluster"
  default     = 2
  validation {
    condition     = var.asg_max_size < 5
    error_message = "Less than 5 please."
  }
}

variable "asg_min_size_jobs" {
  type        = number
  description = "minSize for the cluster"
  default     = 1
  validation {
    condition     = var.asg_min_size_jobs < 2
    error_message = "Less than 3 please."
  }
}

variable "asg_max_size_jobs" {
  type        = number
  description = "maxSize for the cluster"
  default     = 2
  validation {
    condition     = var.asg_max_size_jobs < 3
    error_message = "Less than 5 please."
  }
}
variable "ec2_instance_size" {
  type = string
  description = "The size of instances to use"
  default = "t3a.medium"
}

variable "vpc_id" {}
variable "kms_arn" {}
variable "kms_global_arn" {}
variable "db_cluster_id" {}
variable "log_bucket_arn" {}
variable "scripts_bucket_arn" {}
variable "eb_app_name" {}
variable "ec2_key_name" {}
variable "vpc_subnets_public_ids" {}
variable "vpc_subnets_private_ids" {}
variable "sg_lb_id" {}
variable "wks_ip" {
  default = "184.160.97.226"
}
variable "eb_service_role_arn" {}
variable "shared_alb_arn" {}