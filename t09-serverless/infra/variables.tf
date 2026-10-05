# prefix, owner, suffix and location are set by tools/tofu.sh from config.env

variable "prefix" {
  type = string
}

variable "owner" {
  type = string
}

variable "suffix" {
  type = string
}

variable "location" {
  description = "Region; Flex Consumption is not available everywhere (az functionapp list-flexconsumption-locations)"
  type        = string
}

variable "database_url" {
  description = "Optional PostgreSQL connection string; empty = only store the files"
  type        = string
  default     = ""
  sensitive   = true
}
