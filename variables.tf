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
