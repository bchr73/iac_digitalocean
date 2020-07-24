# variables.tf

variable "do_client_secret" {
  type = string
}

variable "name" {
  type    = string
  default = "staging"
}

variable "region" {
  type    = string
  default = "tor1"
}

variable "droplet_os" {
  type    = string
  default = "ubuntu-16-04-x64"
}

variable "droplet_size" {
  type    = string
  default = "s-1vcpu-1gb"
}

variable "ansible_inventory_file_path" {
  type    = string
  default = "./"
}
