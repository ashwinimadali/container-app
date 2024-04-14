terraform {
  required_providers {
    azurerm = {
        source = "hashicorp/azurerm"
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

# Creating log analytics workspace
resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-aca-terraform" # Ensure the workspace name complies with the rules
  resource_group_name = azurerm_resource_group.my-rg.name
  location            = azurerm_resource_group.my-rg.location
}

# Creating aca environment
resource "azapi_resource" "az_env" {
  type       = "micrcosoft.app/managedenvironments@2022-03-01"
  parent_id  = azurerm_resource_group.my-rg.id # Construct the parent ID correctly
  location   = azurerm_resource_group.my-rg.location
  name       = "aca-env-terraform"

  body = jsonencode({
    properties = {
      applogsconfiguration = {
        destination = "log-analytics"
        loganlyticsconfiguration = {
          customerid = azurerm_log_analytics_workspace.law.workspace_id
          sharedkey  = azurerm_log_analytics_workspace.law.primary_shared_key
        }
      }
    }
  })
}

# Creating the aca (generic resource)
resource "azapi_resource" "az_environment" {
  type = "micrcosoft.app/containerapps@2022-03-01"
  parent_id = azurerm_resource_group.my-rg.id # Construct the parent ID correctly
  location = azurerm_resource_group.my-rg.location
  name = "terraform-app"

  body = jsonencode ({
    properties : {
      managedenvironmentid = azapi_resource.az_env.id # Reference the correct resource
      configuration = {
        ingress = {
          external   = true
          targetport = 80
        }
      }
      template = {
        containers = [
          {
            name     = "web"
            image    = "nginix" # Correct the image name to "nginx"
            resource = {
               CPU    = 0.5
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
