output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "app_gateway_public_ip" {
  description = "Public IP Address of the Application Gateway"
  value       = azurerm_public_ip.appgw.ip_address
}

output "traffic_manager_fqdn" {
  description = "FQDN of the Traffic Manager Profile"
  value       = azurerm_traffic_manager_profile.main.fqdn
}

output "mysql_server_fqdn" {
  description = "FQDN of the Azure MySQL Flexible Server"
  value       = azurerm_mysql_flexible_server.main.fqdn
}

output "database_name" {
  value = azurerm_mysql_flexible_database.main.name
}

output "database_username" {
  value = azurerm_mysql_flexible_server.main.administrator_login
}

output "database_password" {
  value     = var.db_password
  sensitive = true
}

output "vmss_employees_public_ip" {
  description = "Public IP of the Employees Legacy VMSS Load Balancer (for Traffic Manager)"
  value       = azurerm_public_ip.vmss2.ip_address
}

output "app_service_default_hostname" {
  description = "Default hostname of the Modern App Service"
  value       = azurerm_linux_web_app.modern.default_hostname
}
