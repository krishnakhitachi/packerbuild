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
  winrm_timeout                                    = "3m"
  region        = "us-east-1"
  source_ami_filter {
    filters = {
      name                = "Windows_Server-2019-English-Full-Base-2024.03.13"
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
   provisioner "powershell" {
    environment_vars = ["DEVOPS_LIFE_IMPROVER=PACKER"]
    inline           = ["Write-Host \"HELLO NEW USER; WELCOME TO $Env:DEVOPS_LIFE_IMPROVER\"", "Write-Host \"You need to use backtick escapes when using\"", "Write-Host \"characters such as DOLLAR`$ directly in a command\"", "Write-Host \"or in your own scripts.\""]
  }
  provisioner "windows-restart" {
  }
  provisioner "powershell" {
    environment_vars = ["VAR1=A$Dollar", "VAR2=A`Backtick", "VAR3=A'SingleQuote", "VAR4=A\"DoubleQuote"]
    script           = "./sample_script.ps1"
  }
  provisioner "ansible" {
    playbook_file = "./win_playbook.yml"
    user          = "Administrator"
    use_proxy       = false
    extra_arguments = [
      "-e","ansible_winrm_transport=ntlm ansible_winrm_server_cert_validation=ignore"
    ]
  }
}

source "azure-arm" "server_2019" {
  use_azure_cli_auth                               = true
  build_resource_group_name                        = "ManagedImages-RGP"
  build_key_vault_name                             = "Example-Packer-Keyvault"
  os_type                                          = "Windows"
  image_publisher                                  = "MicrosoftWindowsServer"
  image_offer                                      = "WindowsServer"
  image_sku                                        = "2019-Datacenter"
  vm_size                                          = "Standard_D2as_v5"
  os_disk_size_gb                                  = 130
  shared_gallery_image_version_exclude_from_latest = false
  virtual_network_resource_group_name              = "VNET-Resource-Group"
  virtual_network_name                             = "My-VNET"
  virtual_network_subnet_name                      = "My-Subnet"
  private_virtual_network_with_public_ip           = false
  communicator                                     = "winrm"
  winrm_use_ssl                                    = true
  winrm_insecure                                   = true
  winrm_timeout                                    = "3m"
  winrm_username                                   = "Administrator"
  managed_image_name                               = "Managed-Image-Name"
  managed_image_resource_group_name                = "ManagedImages-RGP"
  managed_image_storage_account_type               = "Standard_LRS"

  shared_image_gallery_destination {
    resource_group       = "ManagedImages-RGP"
    gallery_name         = "MyGallery"
    image_name           = "Server2019"
    storage_account_type = "Standard_LRS"
  }
}

build {

  name = "learn-packer-windows2"
  sources = [
    "source.amazon-ebs.windows",
  ]

  provisioner "shell-local" {
    inline_shebang = "/bin/bash -e"
    inline = [
      "pip install --upgrade virtualenv",
      "pip install pywinrm",
      "ansible --version",
      "pip list",
      "pip install requests",
      "pip list",
    ]
  }

  provisioner "powershell" {
    script = "./ConfigureRemotingForAnsible.ps1"
  }

  provisioner "ansible" {
    skip_version_check  = false
    user                = "Administrator"
    use_proxy           = false
    playbook_file       = "./win_playbook.yml"
    extra_arguments = [
      "-e",
      "ansible_winrm_server_cert_validation=ignore",
      "-e",
      "ansible_winrm_transport=ntlm"
    ]
  }
}

# This example uses a amazon-ami data source rather than a specific AMI.
# this allows us to use the same filter regardless of what region we're in,
# among other benefits.
data "amazon-ami" "example" {
  filters = {
    virtualization-type = "hvm"
    name                = "Windows_Server-2019-English-Full-Base-2024.03.13"
    root-device-type    = "ebs"
  }
  owners      = ["amazon"]
  most_recent = true
  # Access Region Configuration
  region      = "us-east-1"
}

source "amazon-ebs" "winrm-example" {
  region =  "us-east-1"
  source_ami = data.amazon-ami.example.id
  instance_type =  "t2.micro"
  ami_name =  "packer_winrm_example {{timestamp}}"
  # This user data file sets up winrm and configures it so that the connection
  # from Packer is allowed. Without this file being set, Packer will not
  # connect to the instance.
  user_data_file = "./autogenerated_password_https_bootstrap.txt"
  communicator = "winrm"
  force_deregister = true
  winrm_insecure = true
  winrm_username = "Administrator"
  winrm_use_ssl = true
}

build {
  name = "learn-packer-windows3"
  sources = [
    "source.amazon-ebs.winrm-example"
  ]

  provisioner "shell-local" {
    inline_shebang = "/bin/bash -e"
    inline = [
      "pip install --upgrade virtualenv",
      "pip install pywinrm",
      "ansible --version",
      "pip list",
      "pip install requests",
      "pip install awx",
      "pip list",
    ]
  }

  provisioner "ansible" {
    playbook_file = "./win_playbook.yml"
    user          = "Administrator"
    use_proxy       = false
    extra_arguments = [
      "-e","ansible_winrm_transport=ntlm ansible_winrm_server_cert_validation=ignore"
    ]
  }
}
