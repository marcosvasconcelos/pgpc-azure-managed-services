# Load Balancer for VMSS 2 (Employees) needed for Traffic Manager
resource "azurerm_lb" "vmss2" {
  name                = "${var.project_name}-vmss2-lb"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.vmss2.id
  }
}

resource "azurerm_lb_backend_address_pool" "vmss2" {
  loadbalancer_id = azurerm_lb.vmss2.id
  name            = "BackEndAddressPool"
}

resource "azurerm_lb_rule" "vmss2_http" {
  loadbalancer_id                = azurerm_lb.vmss2.id
  name                           = "LBRule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.vmss2.id]
  probe_id                       = azurerm_lb_probe.vmss2_http.id
}

resource "azurerm_lb_probe" "vmss2_http" {
  loadbalancer_id = azurerm_lb.vmss2.id
  name            = "http-probe"
  port            = 80
}

# VMSS 1 - Webapp-sp (Python Legacy)
resource "azurerm_linux_virtual_machine_scale_set" "vmss1" {
  name                            = "webapp-sp-vmss"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = var.location
  sku                             = "Standard_B1s"
  instances                       = 1
  admin_username                  = var.admin_username
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS" # Free/Cheaper than Premium
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "webapp-nic"
    primary = true

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.vmss1.id
      application_gateway_backend_address_pool_ids = [
        "${azurerm_application_gateway.main.id}/backendAddressPools/webapp-beap"
      ]
      public_ip_address {
        name = "vmss1-public-ip"
      }
    }
  }

  user_data = base64encode(file("${path.module}/templates/webapp_boot.sh"))

  tags = var.tags
}

# VMSS 2 - Employees-sp (PHP Legacy)
resource "azurerm_linux_virtual_machine_scale_set" "vmss2" {
  name                            = "employees-sp-vmss"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = var.location
  sku                             = "Standard_B1s"
  instances                       = 1
  admin_username                  = var.admin_username
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS" # Free/Cheaper than Premium
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "employees-nic"
    primary = true

    ip_configuration {
      name                                   = "internal"
      primary                                = true
      subnet_id                              = azurerm_subnet.vmss2.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.vmss2.id]
      public_ip_address {
        name = "vmss2-public-ip"
      }
    }
  }

  user_data = base64encode(templatefile("${path.module}/templates/employees.tftpl", {
    db_user     = "mysqladmin"
    db_password = var.db_password
    db_name     = azurerm_mysql_flexible_database.main.name
    db_host     = azurerm_mysql_flexible_server.main.fqdn
  }))

  tags = var.tags
}

# App Service (Modern)
resource "azurerm_service_plan" "modern" {
  name                = "modern-asp"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "F1"
  tags                = var.tags
}

resource "azurerm_linux_web_app" "modern" {
  name                = "modern-app-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  service_plan_id     = azurerm_service_plan.modern.id

  site_config {
    application_stack {
      php_version = "8.0"
    }
    always_on = false
  }

  app_settings = {
    "DB_USER"                        = "mysqladmin"
    "DB_PASS"                        = var.db_password
    "DB_NAME"                        = azurerm_mysql_flexible_database.main.name
    "DB_HOST"                        = azurerm_mysql_flexible_server.main.fqdn
    "SCM_DO_BUILD_DURING_DEPLOYMENT" = "true"
  }

  tags = var.tags
}
