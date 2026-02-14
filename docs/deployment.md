# Deployment Guide

## Prerequisites
- **Azure CLI**: Ensure you are logged in (`az login`).
- **Terraform**: Version 1.0+ installed.
- **Git**: For cloning the repository.
- **Jq**: Optional, for JSON processing if needed.

## Setup
1. **Navigate to the project root:**
   Ensure you are in the root of the repository.

2. **Make the deployment script executable:**
   ```bash
   chmod +x scripts/deploy.sh
   ```

## Deployment Steps

### 1. Initialize Terraform
Run the initialization command to download providers and setup the backend (local by default).
```bash
./scripts/deploy.sh init
```

### 2. Plan the Deployment
Review the changes that will be made to your Azure subscription.
```bash
./scripts/deploy.sh plan
```

### 3. Apply the Configuration
Provision the infrastructure. Type `yes` when prompted.
```bash
./scripts/deploy.sh apply
```

### 4. Post-Deployment Logic
After a successful apply, the script will output key information:
- **Application Gateway IP**: The main entry point.
- **Traffic Manager FQDN**: The routing layer for the employee app.
- **Database Host**: The MySQL server address.

## Verification & Testing

### 1. Database Connectivity (MySQL)
Verify that the database is accessible and credentials are correct.
*   **Host**: Check Terraform output `mysql_server_fqdn`.
*   **User**: `mysqladmin` (or as defined).
*   **Password**: The value you set in `.env` (`TF_VAR_db_password`).

**Test Command:**
```bash
# Load credentials
source scripts/.env

# Connect via mysql client
mysql -h <mysql_server_fqdn> -u mysqladmin -p
# Enter password when prompted
```

**SQL Check:**
```sql
SHOW DATABASES;
USE employees;
SHOW TABLES;
```

### 2. Legacy Application (Python) - Root Path
Access the main entry point via Application Gateway.
*   **URL**: `http://<APP_GATEWAY_IP>/`
*   **Expected Result**: You should see the "LiftShift-Application" homepage served by the Python VM Scale Set.

### 3. Canary Deployment (PHP) - /employees Path
Test the routing between the Legacy (VMSS) and Modern (App Service) systems.
*   **URL**: `http://<APP_GATEWAY_IP>/employees/`
*   **Behavior**:
    *   **Legacy (90%)**: Most requests should hit the VM Scale Set (PHP).
    *   **Modern (10%)**: Some requests should hit the Azure App Service.
*   **Verification**: Refresh the page multiple times. You might see slight differences in the response headers or content depending on which backend served the request (you can inspect headers for `Server` or custom identifiers).

### 4. Traffic Manager Direct Access (Optional)
You can test the Traffic Manager profile directly to verify DNS resolution.
*   **URL**: `http://<TRAFFIC_MANAGER_FQDN>/`
*   **Expected Result**: It should resolve to the IP of the active endpoint (Legacy VMSS Load Balancer or Modern App Service).
   
## Clean Up
To destroy all resources and avoid costs:
```bash
./scripts/deploy.sh destroy
```
