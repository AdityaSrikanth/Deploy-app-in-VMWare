variable "VMName" {}

provider "vsphere" {
  user           = "administrator@rllab.local"
  password       = "Pass@123"
  vsphere_server = "192.168.150.25"

  # If you have a self-signed cert
  allow_unverified_ssl = true
}

data "vsphere_datacenter" "dc" {
  name = "DC001"
}

data "vsphere_datastore" "datastore" {
  name          = "datastore1"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_resource_pool" "pool" {
  name          = "Resourcepool001"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_virtual_machine" "template" {
  name          = "Catalyst"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_network" "network" {
  name          = "VM Network"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

variable "remote_connection" {
  type        = "map"
  description = "Configuration details for connecting to the remote machine"

  default = {
    # Default to SSH
    connection_type = "ssh"

    # User to connect to the server
    connection_user = "adithya"

    # Password to connect to the server
    connection_password = "Pass@123"
  }
}

# My connections for the Chef server
variable "chef_provision" {
  type        = "map"
  description = "Configuration details for chef server"

  default = {
    # A default node name
    node_name_default = "terraform-1"

    # Run it again? You probably need to recreate the client
    recreate_client = true

    # Chef server :)
    server_url = "https://manage.chef.io/organizations/rl_adi/"

    # SSL is lame, so lets turn it off
    ssl_verify_mode_setting = ":verify_none"

    # The username that you authenticate your chef server
    user_name = "adithya_s"
  }
}

resource "vsphere_virtual_machine" "Petclinic_VM" {
  name             = "${var.VMName}"
  resource_pool_id = "${data.vsphere_resource_pool.pool.id}"
  datastore_id     = "${data.vsphere_datastore.datastore.id}"

  num_cpus = 2
  memory   = 1024
  guest_id = "ubuntu64Guest"

  network_interface {
    network_id   = "${data.vsphere_network.network.id}"
    adapter_type = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
  }

  disk {
    label            = "disk0"
    size             = "${data.vsphere_virtual_machine.template.disks.0.size}"
    thin_provisioned = "${data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
    eagerly_scrub    = "${data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
  }

  clone {
    template_uuid = "${data.vsphere_virtual_machine.template.id}"
    timeout       = "10"
  }

  # remote execution provisioner
  provisioner "remote-exec" {
    inline = [
      "git clone https://github.com/spring-projects/spring-petclinic.git",
      "cd spring-petclinic",
      "nohup ./mvnw spring-boot:run &",
    ]

    connection {
      type     = "${var.remote_connection.["connection_type"]}"
      user     = "${var.remote_connection.["connection_user"]}"
      password = "${var.remote_connection.["connection_password"]}"
    }
  }
}
