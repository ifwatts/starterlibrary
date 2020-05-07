################################################################
# Module to deploy Single VM
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Licensed Materials - Property of IBM
#
# Copyright IBM Corp. 2017.
#
################################################################
variable "openstack_image_id" {
  description = "The ID of the image to be used for deploy operations."
}

variable "openstack_flavor_id" {
  description = "The ID of the flavor to be used for deploy operations."
}

variable "openstack_network_name" {
  description = "The name of the network to be used for deploy operations."
}

variable "openstack_volume_size" {
  description = "The size of the storage volume to be attached to the vm."
}

variable "image_user_id" {
 description = "the user id to access the system image"
}

variable "image_user_pwd" {
 description = "the user pwd used to connect to the image"
}

variable "user_id" {
   description = "the user id to add to the system for access"
}
variable "user_pwd" {
  description = "the pwd for the user to log in with"
}

variable "key_pair_name" {
  description = "The name of a ssh key pair which will be injected into the instance when they are created. The key pair must already be created and associated with the tenant's account. Changing key pair name creates a new instance."
  default = ""
}

variable "instance_name" {
	description = "A unique instance name. If a name is not provided a name would be generated."
}

# Generate a random padding
resource "random_id" "random_padding" {
  byte_length = "2"
}


provider "openstack" {
  insecure = true
  version  = "~> 0.3"
}

resource "openstack_blockstorage_volume_v2" "volume_1" {
  name = "volume_1"
  size = ${var.openstack_volume_size}
}

resource "openstack_compute_instance_v2" "single-vm" {
  name      = "${ length(var.instance_name) > 0 ? var.instance_name : format("terraform-single-vm-${random_id.random_padding.hex}-%02d", count.index+1)}"
  image_id  = "${var.openstack_image_id}"
  flavor_id = "${var.openstack_flavor_id}"
  #key_pair  = "${var.key_pair_name}"

  network {
    name = "${var.openstack_network_name}"
  }

  # Specify the ssh connection
  connection {
    user     = "${var.image_user_id}"
    password = "${var.image_user_pwd}"
    timeout  = "10m"
  }

  # Creates a file to add a user and set it's password
  provisioner "file" {
    content = <<EOF
#!/bin/bash
USER=$1
PASSWORD=$2
sudo useradd -m $USER
echo -e "$${PASSWORD}\n$${PASSWORD}" | (sudo passwd $USER)
EOF

    destination = "/tmp/addUser.sh"
  }

  # Execute the script remotely
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/addUser.sh; sudo bash /tmp/addUser.sh \"${var.user_id}\" \"${var.user_pwd}\"",
    ]
  }

  #Adds user to a custom imported sudoers file
  provisioner "file" {
    content = <<EOF
# Created by Cloud Automation Manager
# User rules for ${var.user_id}
${var.user_id} ALL=(ALL) NOPASSWD:ALL
EOF
    destination = "/etc/sudoers.d/cam-added-users"
  }

  resource "openstack_compute_volume_attach_v2" "va_1" {
    instance_id = "${openstack_compute_instance_v2.instance_1.id}"
    volume_id   = "${openstack_blockstorage_volume_v2.volume_1.id}"
  }

}

output "single-vm-ip" {
  value = "${element(openstack_compute_instance_v2.single-vm.*.network.0.fixed_ip_v4,0)}"
}
