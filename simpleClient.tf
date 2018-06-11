
# https://github.com/terraform-providers/terraform-provider-azurerm/issues/233
# https://github.com/hashicorp/terraform/issues/11718
# https://github.com/hashicorp/terraform/pull/11290/files
# https://getintodevops.com/blog/using-ansible-with-terraform
# https://github.com/hashicorp/terraform/issues/6634

variable "subscription_id" {}
variable "client_id" {}
variable "client_secret" {}
variable "tenant_id" {}

#
# Setup the azure provodier
#
provider "azurerm" {
  subscription_id 	= "${var.subscription_id}"
  client_id 		= "${var.client_id}"
  client_secret 	= "${var.client_secret}"
  tenant_id 		= "${var.tenant_id}"
}

#
# Configure a resource group to place all of the configuration into
#
resource "azurerm_resource_group" "poepping_group" {
        name = "testResourceGroup"
        location = "westus"
}

#
# Configure the network for these virutal machines
#
resource "azurerm_virtual_network" "poepping_network" { 
    name		= "myVNet"
    address_space       = ["10.0.0.0/16"]
    location            = "westus"
    resource_group_name = "${azurerm_resource_group.poepping_group.name}"

    tags {
        environment = "Terraform Demo"
    }
}

#
# Configure a subnet in the network for these machines to live on
#
resource "azurerm_subnet" "poepping_subnet" {
    name                 = "mySubnet"
    resource_group_name  = "${azurerm_resource_group.poepping_group.name}"
    virtual_network_name = "${azurerm_virtual_network.poepping_network.name}"
    address_prefix       = "10.0.2.0/24"
}

#
# Configure a Public IP so we can get to these machines when they come up
#
resource "azurerm_public_ip" "poepping_public_ip" {
    count			 = 2
    name                         = "myPublicIP.${count.index}"
    domain_name_label            = "myvm-09983-${count.index}"
    resource_group_name          = "${azurerm_resource_group.poepping_group.name}"
    public_ip_address_allocation = "dynamic"
    location = "westus"

    tags {
        environment = "Terraform Demo"
    }
}


#
# Configure the security group to give access to the ports we need for this machine
#
resource "azurerm_network_security_group" "poepping_security_group" {
    name                = "myNetworkSecurityGroup"
    location            = "westus"
    resource_group_name = "${azurerm_resource_group.poepping_group.name}"

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags {
        environment = "Terraform Demo"
    }
}

#
# Create a virtual NIC to connect to the vm
#
resource "azurerm_network_interface" "poepping_nic_interface" {
    count		= 2
    name                = "myNIC.${count.index}"
    location            = "westus"
    resource_group_name = "${azurerm_resource_group.poepping_group.name}"

    ip_configuration {
        name                          = "myNicConfigurationPublic"
        subnet_id                     = "${azurerm_subnet.poepping_subnet.id}"
        private_ip_address_allocation = "dynamic"
        #public_ip_address_id          = "${azurerm_public_ip.poepping_public_ip.*.id}"
        public_ip_address_id          = "${element(azurerm_public_ip.poepping_public_ip.*.id, count.index )}"
        primary             = true
    }

    tags {
        environment = "Terraform Demo"
    }
}


#
# Now create some virtual machines and place them in the correct place
#
resource "azurerm_virtual_machine" "myterraformvm" {
    count		  = 2
    name                  = "myVM${count.index}"
    location              = "westus"
    resource_group_name   = "${azurerm_resource_group.poepping_group.name}"
    network_interface_ids = [ "${element(azurerm_network_interface.poepping_nic_interface.*.id, count.index )}" ]
    #primary_network_interface_id = "${element(azurerm_network_interface.poepping_nic_interface.*.id, count.index )}"
    vm_size               = "Standard_DS1_v2"

    storage_os_disk {
        name              = "myOsDisk${count.index}"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "16.04.0-LTS"
        version   = "latest"
    }

    os_profile {
        computer_name  = "myvm-${count.index}"
        admin_username = "azureuser"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/azureuser/.ssh/authorized_keys"
            key_data = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC9BVKr2PTL/bqVknEoCDSNIFebQ585x8LDghWU961srpsr7ah8ASiPR/ZhO6oBvhlkQb0msrPFp8t31XOxVxwI6VH2jq/+UXxLA7lUhDfgxc4wrgnSKjoXrHLMJTc9s1t6om6S+vP6hhvnCQ6MShGVUeYmJH5bmOkFOLui/1RzKjHCMKOnBIOPC2e8Ng33naCQzcO6l3cHfwYhUF04pN0WQ5Kl6m3P8/fCdcaWfpV3sfoK4qpe8MGHZQUi8uAyXWe91VhljuLwpN9sWBYneVqCInuNPxgeng8j50TuG7HEqM9C+k7r5lrH0L1qf9L5a8O1BL1GtuTEa55/LjmaSwtJ mattpoepping@Matts-MacBook-Pro-2.local"
        }
    }

    tags {
        environment = "Terraform Demo"
    }

    #provisioner "local-exec" {
    #    command = "echo ${element(azurerm_public_ip.poepping_public_ip.*.fqdn , count.index )} >> ipdata.txt"
    #    on_failure = "continue"
    #}

    #provisioner "local-exec" {
    #    command = "sleep 60; ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u azureuser --private-key ~/.ssh/azuer -i '${element(azurerm_public_ip.poepping_public_ip.*.fqdn , count.index )}' master.yml"
    #    on_failure = "continue"
    #}
}

output "public_ip_dns_name" {
  description = "fqdn to connect to the first vm provisioned."
  value       = "${azurerm_public_ip.poepping_public_ip.*.fqdn}"
}


