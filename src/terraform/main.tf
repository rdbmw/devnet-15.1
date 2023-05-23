provider "yandex" {
  token     = var.yc_token
  cloud_id  = var.yc_cloud_id
  folder_id = var.yc_folder_id
  zone      = var.yc_region
}


data "yandex_compute_image" "nat_image" {
  image_id = "fd80mrhj8fl2oe87o4e1"
}

data "yandex_compute_image" "image" {
  family = "ubuntu-2004-lts"
}

resource "yandex_compute_instance" "nat" {
  name       = "nat-instance"
  
  resources {
    cores  = 2
    memory = 2
  }
  
  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.nat_image.id
    }
  }
  
  network_interface {
    subnet_id = yandex_vpc_subnet.subnet_1.id
    ip_address = "192.168.10.254"
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

resource "yandex_compute_instance" "vm_1" {
  name       = "vm-public"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.image.id
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet_1.id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

resource "yandex_compute_instance" "vm_2" {
  name       = "vm-private"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.image.id
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet_2.id
    nat       = false
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

resource "yandex_vpc_network" "network_1" {
  name = "default"
}

resource "yandex_vpc_subnet" "subnet_1" {
  name           = "public"
  zone           = var.yc_region
  network_id     = yandex_vpc_network.network_1.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

resource "yandex_vpc_route_table" "route" {
  name       = "route-1"
  network_id = yandex_vpc_network.network_1.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    next_hop_address   = yandex_compute_instance.nat.network_interface.0.ip_address
  }
}

resource "yandex_vpc_subnet" "subnet_2" {
  name           = "private"
  zone           = var.yc_region
  network_id     = yandex_vpc_network.network_1.id
  v4_cidr_blocks = ["192.168.20.0/24"]
  route_table_id = yandex_vpc_route_table.route.id
}

output "internal_ip_address_NAT_instance" {
  value = yandex_compute_instance.nat.network_interface.0.ip_address
}
output "external_ip_address_NAT_instance" {
  value = yandex_compute_instance.nat.network_interface.0.nat_ip_address
}

output "internal_ip_address_vm_public" {
  value = yandex_compute_instance.vm_1.network_interface.0.ip_address
}
output "external_ip_address_vm_public" {
  value = yandex_compute_instance.vm_1.network_interface.0.nat_ip_address
}

output "internal_ip_address_vm_private" {
  value = yandex_compute_instance.vm_2.network_interface.0.ip_address
}
output "external_ip_address_vm_private" {
  value = yandex_compute_instance.vm_2.network_interface.0.nat_ip_address
}
