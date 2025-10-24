# Specify the terraform provider
provider "azurerm" {
    features {}
}

# Create a resource group
resource "azurerm_resource_group" "example" {
    name = "terraform-rg"
    location = "East US"
}

# Output the resource group name after creation 
output "resource_group_name" {
    value = azurerm_resource_group.example.name
}