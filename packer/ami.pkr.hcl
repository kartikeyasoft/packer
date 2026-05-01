packer {
  required_plugins {
    ansible = {
      version = "~> 1"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

variable "service_name" {
  type    = string
  default = "ami"
}

variable "service_version" {
  type    = string
  default = "1.0.0"
}

variable "build_number" {
  type    = string
  default = ""
}

variable "source_ami" {
  type    = string
  default = "ami-053b0d53c279acc90"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
  # Use build number if provided, otherwise use timestamp
  build_id = var.build_number != "" ? var.build_number : local.timestamp
}

source "amazon-ebs" "ami" {
  ami_name      = "${var.service_name}-${var.service_version}-${local.build_id}"
  instance_type = "t3.micro"
  region        = var.aws_region
  source_ami    = var.source_ami
  ssh_username  = "ubuntu"
  ssh_timeout   = "10m"
}

build {
  sources = ["source.amazon-ebs.ami"]

  provisioner "ansible" {
    playbook_file = "./ansible/playbook-ami.yml"
    user          = "ubuntu"
    extra_arguments = [
      "--verbose",
      "--ssh-extra-args=-o StrictHostKeyChecking=no"
    ]
  }
}
