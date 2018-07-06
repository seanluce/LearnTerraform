provider "aws" {
  region = "us-east-1"
}

provider "azure" {}

# AWS
resource "aws_key_pair" "seanluce" {
  key_name   = "seanluce"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDbiir97HKZw0XZTyYZwPr37cF+HmsRpDEiVdUoqgFW0JOiGq3xowZVjPbVgTRe5XPqTWlKtSbYH0sgSIY8u4XE2F1smiHt7i+ZIVxrhNNzYUt3Z5juVmJJIqYAcpELt+2JMKmjCRXvmGj2KRk+jSObQj2WsfZ653qRQqpxG1ExMQ+zmovfUe3gzMpmr9udJhkLyqs5w9Kilv6vuud6vdlLiiSTH6BR9pGcxSeDrh3nQlV+6oUJtlXmyezEd1CGMq7uwh2jgdrTxbv2WQscWVdD3sfkbBAQ22nnAji5jjmEmdywTfxG73YRRYGT5Rpv3BeuQH2VpTr77CwQNPXmOs5qJfBcOdvMSvwt3nLtqN+YcH28g7BWLN5yLnHFOIrekwGUBkz0n/oLEan1pXLqmVXc+5FNDWegrjRtrPiRIXq+3kTSY4vThFNys/5n85umAnKng/c6+ymO+zFwgZ1Lt/h5K4VXAdzIslzsAslyjpska014vS+BdO21CsJeMHmvN8IqZLsuWJAQPJZccBiMXRN+jJKOFYlF8xdtZYVw3INP1o7YFivNIzA1LXarNPHFrdZK1j6eQM63gmvh+HJnHpMYTGCoTxmlhG4aSomp+lmSIW2UwiAFIe+df6Q2wJwh8KSOmDvEAOLSak4S2yLZJhkl++fVoPuQcqRWE0YYtcfrrQ== lucesean@gmail.com"
}

resource "aws_vpc" "main" {
  name       = "terraform_vpc"
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "backend" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "10.0.1.0/24"
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.main.id}"
}

resource "aws_route" "r" {
  route_table_id         = "${aws_vpc.main.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.gw.id}"
}

resource "aws_security_group" "sshworld" {
  vpc_id      = "${aws_vpc.main.id}"
  name        = "sshworld"
  description = "Allow SSH from the world"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "example" {
  subnet_id                   = "${aws_subnet.backend.id}"
  ami                         = "ami-b374d5a5"
  associate_public_ip_address = 1
  instance_type               = "t2.micro"
  key_name                    = "${aws_key_pair.seanluce.id}"
  vpc_security_group_ids      = ["${aws_security_group.sshworld.id}"]
}

output "ip" {
  value = "${aws_instance.example.public_ip}"
}

# Azure
resource "azurerm_resource_group" "rg" {
  name     = "terraform_rg"
  location = "East US"
}

resource "azurerm_virtual_network" "network" {
  name                = "production"
  address_space       = ["10.0.0.0/16"]
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
}

resource "azurerm_subnet" "frontend" {
  name                 = "frontend"
  resource_group_name  = "${azurerm_resource_group.rg.name}"
  virtual_network_name = "${azurerm_virtual_network.network.name}"
  address_prefix       = "10.0.1.0/24"
}

resource "azurerm_network_interface" "eth0" {
  name                      = "eth0"
  location                  = "${azurerm_resource_group.rg.location}"
  resource_group_name       = "${azurerm_resource_group.rg.name}"
  network_security_group_id = "${azurerm_network_security_group.myterraformnsg.id}"

  ip_configuration {
    name                          = "private"
    subnet_id                     = "${azurerm_subnet.frontend.id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${azurerm_public_ip.myterraformpublicip.id}"
  }
}

resource "azurerm_public_ip" "myterraformpublicip" {
  name                         = "myPublicIP"
  location                     = "${azurerm_resource_group.rg.location}"
  resource_group_name          = "${azurerm_resource_group.rg.name}"
  public_ip_address_allocation = "dynamic"
}

resource "azurerm_network_security_group" "myterraformnsg" {
  name                = "TerraformSG"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"

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
}

resource "azurerm_managed_disk" "mydisk" {
  name                 = "datadisk_existing"
  location             = "${azurerm_resource_group.rg.location}"
  resource_group_name  = "${azurerm_resource_group.rg.name}"
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "1023"
}

resource "azurerm_virtual_machine" "terraform_vm" {
  name                             = "terraform_vm"
  location                         = "${azurerm_resource_group.rg.location}"
  resource_group_name              = "${azurerm_resource_group.rg.name}"
  network_interface_ids            = ["${azurerm_network_interface.eth0.id}"]
  vm_size                          = "Standard_DS1_v2"
  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "seansean"
    admin_username = "ubuntu"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/ubuntu/.ssh/authorized_keys"
      key_data = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDbiir97HKZw0XZTyYZwPr37cF+HmsRpDEiVdUoqgFW0JOiGq3xowZVjPbVgTRe5XPqTWlKtSbYH0sgSIY8u4XE2F1smiHt7i+ZIVxrhNNzYUt3Z5juVmJJIqYAcpELt+2JMKmjCRXvmGj2KRk+jSObQj2WsfZ653qRQqpxG1ExMQ+zmovfUe3gzMpmr9udJhkLyqs5w9Kilv6vuud6vdlLiiSTH6BR9pGcxSeDrh3nQlV+6oUJtlXmyezEd1CGMq7uwh2jgdrTxbv2WQscWVdD3sfkbBAQ22nnAji5jjmEmdywTfxG73YRRYGT5Rpv3BeuQH2VpTr77CwQNPXmOs5qJfBcOdvMSvwt3nLtqN+YcH28g7BWLN5yLnHFOIrekwGUBkz0n/oLEan1pXLqmVXc+5FNDWegrjRtrPiRIXq+3kTSY4vThFNys/5n85umAnKng/c6+ymO+zFwgZ1Lt/h5K4VXAdzIslzsAslyjpska014vS+BdO21CsJeMHmvN8IqZLsuWJAQPJZccBiMXRN+jJKOFYlF8xdtZYVw3INP1o7YFivNIzA1LXarNPHFrdZK1j6eQM63gmvh+HJnHpMYTGCoTxmlhG4aSomp+lmSIW2UwiAFIe+df6Q2wJwh8KSOmDvEAOLSak4S2yLZJhkl++fVoPuQcqRWE0YYtcfrrQ== lucesean@gmail.com"
    }
  }
}
