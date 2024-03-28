packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
    ansible = {
      version = ">= 1.1.1"
      source  = "github.com/hashicorp/ansible"
    }
  }
}



locals { timestamp = regex_replace(timestamp(), "[- TZ:]", "") }

source "amazon-ebs" "ubuntu" {
  ami_name      = "learn-packer-linux-aws"
  instance_type = "t2.micro"
  region        = "us-east-1"
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/*ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]
  }
  ssh_username = "ubuntu"
}

source "amazon-ebs" "windows" {
  ami_name      = "packer-windows-demo-${local.timestamp}"
  instance_type = "t2.micro"
  communicator  = "winrm"
  region        = "us-east-1"
  source_ami_filter {
    filters = {
      name                = "Windows_Server-2022-English-Full-Base-2024.02.14"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["amazon"]
  }
  user_data_file = "./bootstrap_win.txt"
  winrm_username = "Administrator"
  winrm_password = "SuperS3cr3t!!!!"
}

build {
  name = "learn-packer"
  sources = [
    "source.amazon-ebs.ubuntu"
  ]
  provisioner "ansible" {
    playbook_file = "./playbook.yml"
    user          = "ubuntu"
  }
}

build {
  name = "learn-packer-windows"
  sources = [
    "source.amazon-ebs.windows"
  ]
  provisioner "ansible" {
    playbook_file = "./win_playbook.yml"
    user          = "Administrator"
    use_proxy       = false
    extra_arguments = [
      "-e",
      "ansible_winrm_server_cert_validation=ignore",
      "-e",
      "ansible_winrm_transport=ntlm",
      "-e", 
      "ansible_python_interpreter=/usr/bin/python3"
    ]
  }
}

