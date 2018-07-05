variable "env" {
  description = "Linux Adept Environment [staging/prod]"
  default = "staging"
}

variable "s3_bucket_name" {
  description = "Bucket Name"
  default = "linuxadept.co.uk"
}

variable "linuxadept_io_primary_domain_name" {
  description = "Domain Name"
  default = "linuxadept.io"
}

variable "linuxadept_io_alias_domains" {
  description = "LinuxAdept IO domains for inclusion"
  type        = "list"
  default     = [""]
}
