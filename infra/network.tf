resource "azurerm_virtual_network" "main" {
  name                = "${var.project_name}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags
}

variable "subnets" {
  default = {
    vmss1 = "10.0.1.0/24"
    vmss2 = "10.0.2.0/24"
    appgw = "10.0.3.0/24"
  }
}

resource "azurerm_subnet" "vmss1" {
  name                 = "vmss1-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnets["vmss1"]]
}

resource "azurerm_subnet" "vmss2" {
  name                 = "vmss2-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnets["vmss2"]]
}

resource "azurerm_subnet" "appgw" {
  name                 = "appgw-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnets["appgw"]]
}

resource "azurerm_public_ip" "appgw" {
  name                = "${var.project_name}-appgw-pip"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "${var.project_name}-appgw-${random_string.suffix.result}"
  tags                = var.tags
}

# Public IP for VMSS 2 Load Balancer (Employees - Legacy)
resource "azurerm_public_ip" "vmss2" {
  name                = "${var.project_name}-vmss2-pip"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "${var.project_name}-vmss2-${random_string.suffix.result}"
  tags                = var.tags
}

# NSG for Subnets
resource "azurerm_network_security_group" "main" {
  name                = "${var.project_name}-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowSSH"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "vmss1" {
  subnet_id                 = azurerm_subnet.vmss1.id
  network_security_group_id = azurerm_network_security_group.main.id
}

resource "azurerm_subnet_network_security_group_association" "vmss2" {
  subnet_id                 = azurerm_subnet.vmss2.id
  network_security_group_id = azurerm_network_security_group.main.id
}
