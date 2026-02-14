# Traffic Manager
resource "azurerm_traffic_manager_profile" "main" {
  name                   = "${var.project_name}-tm-${random_string.suffix.result}"
  resource_group_name    = azurerm_resource_group.main.name
  traffic_routing_method = "Weighted"

  dns_config {
    relative_name = "${var.project_name}-tm-${random_string.suffix.result}"
    ttl           = 60
  }

  monitor_config {
    protocol                     = "HTTP"
    port                         = 80
    path                         = "/"
    interval_in_seconds          = 30
    timeout_in_seconds           = 9
    tolerated_number_of_failures = 3
  }

  tags = var.tags
}

resource "azurerm_traffic_manager_external_endpoint" "vmss2" {
  name       = "legacy-vmss-endpoint"
  profile_id = azurerm_traffic_manager_profile.main.id
  target     = azurerm_public_ip.vmss2.ip_address # External IP of VMSS 2 Load Balancer
  weight     = 90
}

resource "azurerm_traffic_manager_azure_endpoint" "modern" {
  name               = "modern-app-endpoint"
  profile_id         = azurerm_traffic_manager_profile.main.id
  target_resource_id = azurerm_linux_web_app.modern.id
  weight             = 10
}

# Application Gateway
locals {
  appgw_backend_address_pool_name_webapp = "webapp-beap"
  appgw_backend_address_pool_name_tm     = "trafficmanager-beap"
  frontend_port_name                     = "appgw-feport"
  frontend_ip_configuration_name         = "appgw-feip"
  http_setting_name                      = "appgw-be-htst"
  listener_name                          = "appgw-httplstn"
  request_routing_rule_name              = "appgw-rqrt"
  url_path_map_name                      = "appgw-urlpathmap"
}

resource "azurerm_application_gateway" "main" {
  name                = "${var.project_name}-appgw"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 1
  }

  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20170401S"
  }

  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = azurerm_subnet.appgw.id
  }

  frontend_port {
    name = local.frontend_port_name
    port = 80
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.appgw.id
  }

  # Backend Pool 1: Webapp VMSS (VMSS 1)
  backend_address_pool {
    name = local.appgw_backend_address_pool_name_webapp
    # Linking VMSS 1 by IP or referring to it in VMSS config?
    # VMSS nic can be added to this pool, or we can add IPs.
    # We will simply leave it empty here and rely on logic or add IPs if known.
    # Actually, the proper way for VMSS in AppGW is to associating the VMSS Network Interface IP config 
    # to this backend pool. 
    # BUT, Application Gateway Backend Pool can't be easily referenced inside VMSS resource 
    # due to circular dependency if not careful.
    # We will allow the pool to exist, and we need to link VMSS 1 to it.
    # Since we didn't export the AppGW Pool ID to VMSS resource (we can't easily, circular),
    # We can add the VMSS instances IPs... but that's dynamic.
    # Better approach: 
    # 1. Create AppGW.
    # 2. Modify VMSS `ip_configuration` to include `application_gateway_backend_address_pool_ids`.
    # Let's try to update VMSS resource in `compute.tf` to reference this pool? 
    # Cyclic dependency: AppGw depends on Subnet, VMSS depends on Subnet.
    # AppGw -> Backend Pool.
    # VMSS -> AppGw Backend Pool ID.
    # Terraform handles this if we pass the ID.
  }

  # Backend Pool 2: Traffic Manager
  backend_address_pool {
    name  = local.appgw_backend_address_pool_name_tm
    fqdns = [azurerm_traffic_manager_profile.main.fqdn]
  }

  backend_http_settings {
    name                  = local.http_setting_name
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

  request_routing_rule {
    name               = local.request_routing_rule_name
    rule_type          = "PathBasedRouting"
    http_listener_name = local.listener_name
    url_path_map_name  = local.url_path_map_name
    priority           = 1
  }

  url_path_map {
    name                               = local.url_path_map_name
    default_backend_address_pool_name  = local.appgw_backend_address_pool_name_webapp
    default_backend_http_settings_name = local.http_setting_name

    path_rule {
      name                       = "employees-path"
      paths                      = ["/employees/*"]
      backend_address_pool_name  = local.appgw_backend_address_pool_name_tm
      backend_http_settings_name = local.http_setting_name
    }
  }

  tags = var.tags
}
