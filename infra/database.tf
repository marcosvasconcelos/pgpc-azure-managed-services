resource "azurerm_mysql_flexible_server" "main" {
  name                   = "${var.project_name}-mysql-${random_string.suffix.result}"
  resource_group_name    = azurerm_resource_group.main.name
  location               = var.location
  administrator_login    = "mysqladmin"
  administrator_password = var.db_password
  backup_retention_days  = 7
  sku_name               = "B_Standard_B1ms"
  version                = "8.0.21" # Supported version
  tags                   = var.tags
}

resource "azurerm_mysql_flexible_database" "main" {
  name                = "employees"
  resource_group_name = azurerm_resource_group.main.name
  server_name         = azurerm_mysql_flexible_server.main.name
  charset             = "utf8"
  collation           = "utf8_general_ci"
}

resource "azurerm_mysql_flexible_server_firewall_rule" "allow_all" {
  name                = "allow-all"
  resource_group_name = azurerm_resource_group.main.name
  server_name         = azurerm_mysql_flexible_server.main.name
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "255.255.255.255"
}

resource "azurerm_mysql_flexible_server_configuration" "no_ssl" {
  name                = "require_secure_transport"
  resource_group_name = azurerm_resource_group.main.name
  server_name         = azurerm_mysql_flexible_server.main.name
  value               = "OFF"
}
