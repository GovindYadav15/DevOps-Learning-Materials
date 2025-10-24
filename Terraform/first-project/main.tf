# Specify the provider name
provider "azurerm" {
    features {
      
    }
}

# Create a resource group
resource "azurerm_resource_group" "my-rg" {
    name = "my-terraform-rg"
    location = "West Europe"
}