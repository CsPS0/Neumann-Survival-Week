# Builds the Empty School server VM as an .ova. Run build-ova.sh, which prepares the game context first.
packer {
  required_plugins {
    virtualbox = {
      version = ">= 1.0.5"
      source  = "github.com/hashicorp/virtualbox"
    }
  }
}

variable "iso_url" {
  type    = string
  default = "https://cdimage.debian.org/cdimage/archive/12.11.0/amd64/iso-cd/debian-12.11.0-amd64-netinst.iso"
}

variable "iso_checksum" {
  type    = string
  default = "file:https://cdimage.debian.org/cdimage/archive/12.11.0/amd64/iso-cd/SHA256SUMS"
}

variable "game_context" {
  type        = string
  description = "Tar archive of the HORROR-GAME folder, made by build-ova.sh."
}

variable "memory_mb" {
  type    = number
  default = 1024
}

source "virtualbox-iso" "neumann" {
  vm_name              = "TheEmptySchoolServer"
  guest_os_type        = "Debian12_64"
  iso_url              = var.iso_url
  iso_checksum         = var.iso_checksum
  cpus                 = 1
  memory               = var.memory_mb
  disk_size            = 10240
  hard_drive_interface = "sata"
  guest_additions_mode = "disable"
  headless             = true
  http_directory       = "${path.root}/http"
  boot_wait            = "5s"
  boot_command = [
    "<wait><esc><wait>",
    "auto url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg ",
    "netcfg/get_hostname=neumann-server netcfg/get_domain=local<enter>"
  ]
  ssh_username     = "neumann"
  ssh_password     = "neumann"
  ssh_timeout      = "45m"
  shutdown_command = "sudo systemctl poweroff"
  format           = "ova"
  output_directory = "${path.root}/output"
  vboxmanage = [
    ["modifyvm", "{{ .Name }}", "--audio-enabled", "off"],
    ["modifyvm", "{{ .Name }}", "--usb", "off"],
    ["modifyvm", "{{ .Name }}", "--vram", "4"]
  ]
}

build {
  sources = ["source.virtualbox-iso.neumann"]

  provisioner "file" {
    source      = var.game_context
    destination = "/tmp/game-context.tar"
  }

  provisioner "file" {
    source      = "${path.root}/files"
    destination = "/tmp/vm-files"
  }

  provisioner "shell" {
    script          = "${path.root}/files/provision.sh"
    execute_command = "sudo -E sh '{{ .Path }}'"
  }
}
