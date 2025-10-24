provider "azurerm" {
  features {
    
  }
}

provider "azurerm" {
  alias = "eastus"
  subscription_id = "...."
  features {
    
  }
}

provider "azurerm" {
  alias = "westus"
  subscription_id = "...."
  features {
    
  }
}

resource "azurerm_resource_group" "east-rg" {
    name = "terraform-eastus-rg"
    location = "East US"
    provider = azurerm.eastus
}
resource "azurerm_resource_group" "west-rg" {
    name = "terraform-westus-rg"
    location = "West US"
    provider = azurerm.westus
}