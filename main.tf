terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
    azapi = {
      source = "azure/azapi"
    }
  }  
}

provider "azurerm" {
  features {}
}

provider "azapi" {
}

resource "azurerm_resource_group" "my-rg" {
  name     = "ACATFDemo"
  location = "East US"  
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-aca-terraform"
  resource_group_name = azurerm_resource_group.my-rg.name
  location            = azurerm_resource_group.my-rg.location
}

resource "azapi_resource" "az_env" {
  type       = "microsoft.app/managedenvironments@2022-03-01"
  parent_id  = azurerm_resource_group.my-rg.id
  location   = azurerm_resource_group.my-rg.location
  name       = "aca-env-terraform"

  body = jsonencode({
    properties = {
      appLogsConfiguration = { 
        destination = "log-analytics"
        logAnalyticsConfiguration = { 
          customerId = azurerm_log_analytics_workspace.law.workspace_id
          sharedKey  = azurerm_log_analytics_workspace.law.primary_shared_key
        }
      }
    }
  })
}

resource "azapi_resource" "az_environment" {
  type = "microsoft.app/containerapps@2022-03-01"
  parent_id = azurerm_resource_group.my-rg.id
  location = azurerm_resource_group.my-rg.location
  name = "terraform-app"

  body = jsonencode ({
    properties : {
      managedEnvironmentId = azapi_resource.az_env.id
      configuration = {
        ingress = {
          external   = true
          targetPort = 80
        }
      }
      template = {
        containers = [
          {
            name     = "web"
            image    = "nginx"
            resources = {
               cpu    = 0.5 # Adjusted property name to lowercase
               memory = "1.0Gi"
            }
          }        
        ]
        scale = {
          minReplicas = 2
          maxReplicas = 20
        }
      }
    }
  })
}


