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
  type = string
}

variable "github_repository" {
  description = "Repository that may deploy, e.g. \"jdoe/placefinder\""
  type        = string
}

variable "github_branch" {
  description = "Only workflow runs on this branch get credentials"
  type        = string
  default     = "master"
}
