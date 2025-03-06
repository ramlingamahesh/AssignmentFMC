variable "rg_name" {
  default = "rg-webapp-sb-eu-001"
}


variable "vnet_name" {
  default = "app-sb-eu-001"
}

variable "bastion_subnet" {
  default = "bastion-sb-eu-001"
}


variable "appgw_subnet" {
  default = "snet-appgw-sb-eu"
}


variable "app_subnet_name" {
  default = "snet-app-sb-eu-app-001"
}


 variable "web_subnet_name"{
     default = "snet-web-sb-eu-app-001"

 }

variable "db_subnet_name"{
     default = "snet-db-sb-eu-app-001"

 }

variable "db_subnet_address_space" {
  type    = string
  description = "Subnet Address for the db Subnet"
  default = ""
}

variable "vnet_address_space" {
  type    = string
  description = " Address for the vnet "
  default = ""
}

variable "my_sql_Server"{
    type =string
    description = "mysql db"
    default = " "

 }


variable "location" {
  type    = string
  description = "Location for the resources you deploy"
  default = ""
}

variable "ENVIRONMENT" {
  type    = string
  description = "Environment Name for the resources"
  default = "sb"
}


variable "sku_name" {
  description = "he Name of the SKU used for this Key Vault. Possible values are standard and premium."
  default     = ""
}

## Variables for VMSS

variable "admin_user" {
  description = "User name to use as the admin account on the VMs that will be part of the VM scale set"
  default     = ""
}

variable "instances" {
  description = "The number of Virtual Machines in the Scale Set."
  default     = "2"
}

variable "size" {
  description = "Choose the VM size. Ref: https://aka.ms/WinVMSizes"
  default     = ""
}

variable "vmss_resource_group_name" {
  description = "Resource Group created manually for VMSS image"
  default     = ""
}

variable "storage_account_type" {
  description = "The Type of Storage Account which should back this the Internal OS Disk. Possible values are Standard_LRS, StandardSSD_LRS and Premium_LRS. Changing this forces a new resource to be created."
  default     = ""
}

variable "vmss_linux_image_name" {
  description = "The name of an Image which each Virtual Machine in this Scale Set should be based on."
  default     = ""
}

variable "storage_account" {
  description = "The name of storage account used for storing state file"
  default     = ""
}


/* #  private_service_connection block 

variable "connection_name" {
  description = "Specifies the Name of the Private Service Connection. Changing this forces a new resource to be created."
}

variable "resource_id" {
  description = "The ID of the Private Link Enabled Remote Resource which this Private Endpoint should be connected to. Changing this forces a new resource to be created."
}

variable "subresource_names" {
  description = "A list of subresource names which the Private Endpoint is able to connect to. subresource_names corresponds to group_id. Changing this forces a new resource to be created."
  default     = null
}
 */



