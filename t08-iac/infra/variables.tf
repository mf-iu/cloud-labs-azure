# prefix, owner, suffix, location and placefinder_image are set by
# tools/tofu.sh from config.env

variable "prefix" {
  description = "Project prefix for all names"
  type        = string
}

variable "owner" {
  description = "Initials of the participant"
  type        = string
}

variable "suffix" {
  description = "Random suffix for globally unique names (.state/suffix)"
  type        = string
}

variable "location" {
  description = "Azure region (AZURE_LOCATION in config.env)"
  type        = string
}

variable "placefinder_image" {
  description = "Image repository of PlaceFinder without tag (PLACEFINDER_IMAGE in config.env)"
  type        = string
}

variable "image_tag" {
  description = "Image tag to deploy first; the pipeline deploys later versions"
  type        = string
  default     = "t08"
}

variable "enable_database" {
  description = "Create PostgreSQL in the database subnet (free for 12 months, destroy it after the lab)"
  type        = bool
  default     = false
}

variable "max_replicas" {
  description = "Upper limit for the number of PlaceFinder replicas"
  type        = number
  default     = 2
}
