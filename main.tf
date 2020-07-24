# main.tf

terraform {
  backend "s3" {
    bucket                      = "tfstate-bucket-test"
    key                         = "production/terraform.tfstate"
    region                      = "us-west-1"
    endpoint                    = "https://sfo2.digitaloceanspaces.com"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
  }
}

provider digitalocean {
  token = var.do_client_secret
}

# add ssh keys
data "digitalocean_ssh_key" "home" {
  name = "karim-home"
}

# add ssh keys
data "digitalocean_ssh_key" "github" {
  name = "github-actions"
}

# create domain
resource "digitalocean_domain" "web" {
  name = "karimboucher.com"
}

# create tags
resource "digitalocean_tag" "issuer" {
  name = "issuer"
}
resource "digitalocean_tag" "verifier" {
  name = "verifier"
}
resource "digitalocean_tag" "explorer" {
  name = "explorer"
}

# create issuer droplet
resource "digitalocean_droplet" "issuer" {
  image    = var.droplet_os
  name     = "issuer"
  region   = var.region
  size     = var.droplet_size
  ssh_keys = [data.digitalocean_ssh_key.home.id, data.digitalocean_ssh_key.github.id]
  tags     = [digitalocean_tag.issuer.id]
}

# create verifier droplet
resource "digitalocean_droplet" "verifier" {
  image    = var.droplet_os
  name     = "verifier"
  region   = var.region
  size     = var.droplet_size
  ssh_keys = [data.digitalocean_ssh_key.home.id, data.digitalocean_ssh_key.github.id]
  tags     = [digitalocean_tag.verifier.id]
}

# create blockexplorer droplet
resource "digitalocean_droplet" "explorer" {
  image    = var.droplet_os
  name     = "blockexplorer"
  region   = var.region
  size     = var.droplet_size
  ssh_keys = [data.digitalocean_ssh_key.home.id, data.digitalocean_ssh_key.github.id]
  tags     = [digitalocean_tag.explorer.id]
}

resource "digitalocean_firewall" "web" {
  name = "only-22-80-and-443"

  droplet_ids = concat(digitalocean_droplet.issuer.*.id,
    digitalocean_droplet.verifier.*.id,
  digitalocean_droplet.explorer.*.id)

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

# add 'A' record for issuer
resource "digitalocean_record" "issuer" {
  domain = digitalocean_domain.web.name
  type   = "A"
  name   = "certs"
  value  = digitalocean_droplet.issuer.ipv4_address
  ttl    = 30
}

# add 'A' record for verifier
resource "digitalocean_record" "verifier" {
  domain = digitalocean_domain.web.name
  type   = "A"
  name   = "verify"
  value  = digitalocean_droplet.verifier.ipv4_address
  ttl    = 30
}

# add 'A' record to block explorer
resource "digitalocean_record" "explorer" {
  domain = digitalocean_domain.web.name
  type   = "A"
  name   = "blockexplorer"
  value  = digitalocean_droplet.explorer.ipv4_address
  ttl    = 30
}

# add resources to new project
resource "digitalocean_project" "project" {
  name        = var.name
  description = "Notarizing certificates on ${var.name} blockchain"
  purpose     = "${var.name} Certificates"
  environment = "Production"
  resources = concat(digitalocean_droplet.issuer.*.urn,
    digitalocean_droplet.explorer.*.urn,
    digitalocean_droplet.verifier.*.urn,
  digitalocean_domain.web.*.urn)
}

output "issuer_ip" {
  value = digitalocean_droplet.issuer.*.ipv4_address
}

output "verifier_ip" {
  value = digitalocean_droplet.verifier.*.ipv4_address
}

output "blockexplorer_ip" {
  value = digitalocean_droplet.explorer.*.ipv4_address
}

# create Ansible inventory file
resource "local_file" "AnsibleInventory" {
  content = templatefile("terraform_inv.tpl", {
    public-dns     = digitalocean_domain.web.name,
    issuer-names   = digitalocean_droplet.issuer.*.name
    issuer-ips     = digitalocean_droplet.issuer.*.ipv4_address
    verifier-names = digitalocean_droplet.verifier.*.name
    verifier-ips   = digitalocean_droplet.verifier.*.ipv4_address
    explorer-names = digitalocean_droplet.explorer.*.name
    explorer-ips   = digitalocean_droplet.explorer.*.ipv4_address
  })
  filename = "${var.ansible_inventory_file_path}hosts"
}
