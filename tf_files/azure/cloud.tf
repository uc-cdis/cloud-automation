provider "azurerm" {
  subscription_id = "${var.azure_subscription_id}"
  client_id = "${var.azure_client_id}"
  client_secret = "${var.azure_client_secret}"
  tenant_id = "${var.azure_tenant_id}"
}

resource "azurerm_virtual_network" "main" {
  name = "${var.vpc_name}"
  address_space = ["172.16.0.0/16"]
  resource_group_name = "${var.azure_resource_group_name}"
  location = "${var.azure_region}"
}

resource "azurerm_network_security_group" "kube-worker" {
  name = "kube-worker"
  resource_group_name = "${var.azure_resource_group_name}"
  location = "${var.azure_region}"
  security_rule {
    name = "Inboundfornodeports"
    description = "security group that open ports to vpc, this needs to be attached to kube worker"
    source_port_range = "*"
    destination_port_range = "30000-31000"
    protocol = "TCP"
    direction = "Inbound"
    priority = 102
    access = "Allow"
    source_address_prefix = "172.16.0.0/16"
    destination_address_prefix = "172.16.0.0/16"
  }
  security_rule {
    name = "Inboundforhttps"
    source_port_range = "*"
    destination_port_range = 443
    protocol = "TCP"
    direction = "Inbound"
    priority = 103
    access = "Allow"
    source_address_prefix = "${azurerm_network_interface.kp.private_ip_address}/32"
    destination_address_prefix = "${azurerm_network_interface.kp.private_ip_address}/32"
  }
}

resource "azurerm_network_security_group" "loginnode" {
  name = "loginnode"
  resource_group_name = "${var.azure_resource_group_name}"
  location = "${var.azure_region}"
  security_rule {
      name = "inboundssh2"
      description = "security group that only enables ssh for login node"
      direction = "Inbound"
      priority = 100
      access = "Allow"
      source_port_range = "*"
      destination_port_range = 22
      protocol = "TCP"
      source_address_prefix = "*"
      destination_address_prefix = "172.16.0.0/24"
  }

  security_rule {
    name = "internalinboundallow"
    description = "security group that only allow internal tcp traffics"
    direction = "Inbound"
    priority = 200
    access = "Allow" 
    protocol = "TCP"
    source_port_range = "*"
    destination_port_range = "*" 
    source_address_prefix = "172.16.0.0/16"
    destination_address_prefix = "172.16.0.0/16"
  }
  security_rule {
    name = "internaloutboundallow"
    description = "security group that only allow internal tcp traffics"
    direction = "Outbound"
    priority = 201
    access = "Allow"
    protocol = "TCP"
    source_port_range = "*"
    destination_port_range = "*"
    source_address_prefix = "172.16.0.0/16"
    destination_address_prefix = "172.16.0.0/16"
  }
  security_rule {
    name = "denyalloutbound"
    description = "deny all outbound traffic"
    direction = "Outbound"
    priority = 300
    access = "Deny"
    protocol = "TCP"
    source_port_range = "*"
    destination_port_range = "*"
    source_address_prefix = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "webservice" {
  name = "webservice"
  resource_group_name = "${var.azure_resource_group_name}"
  location = "${var.azure_region}"
  security_rule {
    name = "internalinboundallow"
    description = "security group that only allow internal tcp traffics"
    direction = "Inbound"
    priority = 202
    access = "Allow"
    protocol = "TCP"
    source_port_range = "*"
    destination_port_range = "*"
    source_address_prefix = "172.16.0.0/16"
    destination_address_prefix = "172.16.0.0/16"
  }
  security_rule {
    name = "internaloutboundallow"
    description = "security group that only allow internal tcp traffics"
    direction = "Outbound"
    priority = 203
    access = "Allow"
    protocol = "TCP"
    source_port_range = "*"
    destination_port_range = "*"
    source_address_prefix = "172.16.0.0/16"
    destination_address_prefix = "172.16.0.0/16"
  }
  security_rule {
    name = "httpsallow"
    description = "allow https traffic"
    direction = "Inbound"
    priority = 204
    access = "Allow"
    protocol = "TCP"
    source_port_range = "*"
    destination_port_range = "443"
    source_address_prefix = "*"
    destination_address_prefix = "172.16.0.0/24"
  }
  security_rule {
    name = "httpallow"
    description = "allow http traffic"
    direction = "Inbound"
    priority = 205
    access = "Allow"
    protocol = "TCP"
    source_port_range = "*"
    destination_port_range = "80"
    source_address_prefix = "*"
    destination_address_prefix = "172.16.0.0/24"
  }
  security_rule {
    name = "denyalloutbound"
    description = "deny all outbound traffic"
    direction = "Outbound"
    priority = 300
    access = "Deny"
    protocol = "TCP"
    source_port_range = "*"
    destination_port_range = "*"
    source_address_prefix = "*"
    destination_address_prefix = "*"
  }
}


resource "azurerm_network_security_group" "cloudproxy" {
  name = "cloudproxy"
  resource_group_name = "${var.azure_resource_group_name}"
  location = "${var.azure_region}"
  security_rule {
    name = "cloudproxyallow"
    description = "security group that allow outbound traffics"
    direction = "Outbound"
    priority = 206
    access = "Allow"
    protocol = "TCP"
    source_port_range = "*"
    destination_port_range = "*"
    source_address_prefix = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name = "proxyinboundallow"
    description = "allow inbound tcp at 3128"
    direction = "Inbound"
    priority = 207
    access = "Allow"
    protocol = "TCP"
    source_port_range = "*"
    destination_port_range = "3128"
    source_address_prefix = "0.0.0.0/0"
    destination_address_prefix = "172.16.0.0/16"
  }
}

resource "azurerm_route_table" "public" {
  name = "publicrt"
  resource_group_name = "${var.azure_resource_group_name}"
  location = "${var.azure_region}"
  route {
    name = "routetointernet"
    address_prefix = "0.0.0.0/0"
    next_hop_type= "Internet"
  }
}

resource "azurerm_public_ip" "nat" {
  name = "natip"
  resource_group_name = "${var.azure_resource_group_name}"
  location = "${var.azure_region}"
  public_ip_address_allocation = "Static"
}

resource "azurerm_public_ip" "login" {
  name = "loginip"
  resource_group_name = "${var.azure_resource_group_name}"
  location = "${var.azure_region}"
  public_ip_address_allocation = "Static"
}

resource "azurerm_public_ip" "revproxy" {
  name = "revproxyip"
  resource_group_name = "${var.azure_resource_group_name}"
  location = "${var.azure_region}"
  public_ip_address_allocation = "Static"
}

resource "azurerm_route_table" "private" {
  name = "privatert"
  resource_group_name = "${var.azure_resource_group_name}"
  location = "${var.azure_region}"
  route {
    name = "routetop"
    address_prefix = "0.0.0.0/0"
    next_hop_type = "VnetLocal"
  }
}

resource "azurerm_route_table" "private_2" {
  name = "privatert2"
  resource_group_name = "${var.azure_resource_group_name}"
  location = "${var.azure_region}"
  route {
    name = "routetop2"
    address_prefix = "0.0.0.0/0"
    next_hop_type = "VnetLocal"
  }
}

resource "azurerm_subnet" "public" {
  name = "publicsubnet"
  resource_group_name = "${var.azure_resource_group_name}"
  virtual_network_name = "${azurerm_virtual_network.main.name}"
  address_prefix = "172.16.0.0/24"
  route_table_id = "${azurerm_route_table.public.id}"
}

resource "azurerm_subnet" "public_kube" {
  name = "publickubesubnet"
  resource_group_name = "${var.azure_resource_group_name}"
  virtual_network_name = "${azurerm_virtual_network.main.name}"
  address_prefix = "172.16.1.0/24"
  route_table_id = "${azurerm_route_table.public.id}"
}

resource "azurerm_subnet" "private" {
  name = "privatesubnet"
  resource_group_name = "${var.azure_resource_group_name}"
  virtual_network_name = "${azurerm_virtual_network.main.name}"
  address_prefix = "172.16.16.0/20"
  route_table_id = "${azurerm_route_table.private.id}"
}

resource "azurerm_subnet" "private_2" {
  name = "private2subnet"
  resource_group_name = "${var.azure_resource_group_name}"
  virtual_network_name = "${azurerm_virtual_network.main.name}"
  address_prefix = "172.16.4.0/22"
  route_table_id = "${azurerm_route_table.private_2.id}"
}

resource "azurerm_subnet" "private_3" {
  name = "private3subnet"
  resource_group_name = "${var.azure_resource_group_name}"
  virtual_network_name = "${azurerm_virtual_network.main.name}"
  address_prefix  = "172.16.8.0/21"
}

resource "azurerm_network_interface" "public" {
  name = "public"
  resource_group_name = "${var.azure_resource_group_name}"
  location = "${var.azure_region}"
  network_security_group_id = "${azurerm_network_security_group.loginnode.id}"
  internal_dns_name_label = "headnode"
  ip_configuration {
    name = "publicinterface"
    subnet_id = "${azurerm_subnet.public.id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id = "${azurerm_public_ip.login.id}"
  }
}

resource "azurerm_network_interface" "kp" {
  name = "nickp"
  resource_group_name = "${var.azure_resource_group_name}"
  location = "${var.azure_region}"
  internal_dns_name_label = "kube"
  ip_configuration {
    name = "securityinterface"
    subnet_id = "${azurerm_subnet.private.id}"
    private_ip_address_allocation = "dynamic"
  }
}

resource "azurerm_network_interface" "cloudproxy" {
  name = "niccloudproxy"
  resource_group_name = "${var.azure_resource_group_name}"
  location = "${var.azure_region}"
  internal_dns_name_label = "cloud-proxy"
  network_security_group_id = "${azurerm_network_security_group.cloudproxy.id}"
  ip_configuration {
    name = "cloudproxyinterface"
    subnet_id = "${azurerm_subnet.public.id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id = "${azurerm_public_ip.nat.id}"
  }
}

resource "azurerm_network_interface" "revproxy" {
  name = "nicrevproxy"
  resource_group_name = "${var.azure_resource_group_name}"
  location = "${var.azure_region}"
  internal_dns_name_label = "rev-proxy"
  network_security_group_id = "${azurerm_network_security_group.webservice.id}"
  ip_configuration {
    name = "cloudproxyinterface"
    subnet_id = "${azurerm_subnet.public.id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id = "${azurerm_public_ip.revproxy.id}"
  }
}

resource "azurerm_virtual_machine" "login" {
  name = "LoginNode"
  resource_group_name = "${var.azure_resource_group_name}"
  location = "${var.azure_region}"
  vm_size = "Standard_A0"
  primary_network_interface_id = "${azurerm_network_interface.public.id}"
  network_interface_ids = ["${azurerm_network_interface.public.id}"]
  storage_image_reference {
    id = "${var.login_ami}"
  }
  storage_os_disk {
    name = "logindisk1"
    os_type = "linux"
    create_option   = "FromImage"
  }
  os_profile {
    computer_name  = "login"
    admin_username = "cdis"
    admin_password = "zacr0cks!K"
  }
}

resource "azurerm_virtual_machine" "kube_provisioner" {
  name = "KubeProvisioner"
  resource_group_name = "${var.azure_resource_group_name}"
  location = "${var.azure_region}"
  vm_size = "Standard_A0"
  network_interface_ids = ["${azurerm_network_interface.kp.id}"]
  storage_image_reference {
    id = "${var.login_ami}"
  }
  storage_os_disk {
    name = "kubeprovdisk1"
    os_type = "linux"
    create_option   = "FromImage"
  }
  os_profile {
    computer_name  = "kube-provisioner"
    admin_username = "cdis"
    admin_password = "zacr0cks!K"
  }
}

resource "azurerm_virtual_machine" "proxy" {
  name = "CloudProxy"
  resource_group_name = "${var.azure_resource_group_name}"
  location = "${var.azure_region}"
  vm_size = "Standard_A0"
  network_interface_ids = ["${azurerm_network_interface.cloudproxy.id}"]
  storage_image_reference {
    id = "${var.proxy_ami}"
  }
  storage_os_disk {
    name = "cloudproxydisk1"
    os_type = "linux"
    create_option   = "FromImage"
  }
  os_profile {
    computer_name  = "cloud-proxy"
    admin_username = "cdis"
    admin_password = "zacr0cks!K"
  }
}

resource "azurerm_virtual_machine" "revproxy" {
  name = "RevProxy"
  resource_group_name = "${var.azure_resource_group_name}"
  location = "${var.azure_region}"
  vm_size = "Standard_A0"
  network_interface_ids = ["${azurerm_network_interface.revproxy.id}"]
  storage_image_reference {
    id = "${var.login_ami}"
  }
  storage_os_disk {
    name = "revproxydisk1"
    os_type = "linux"
    create_option   = "FromImage"
  }
  os_profile {
    computer_name  = "rev-proxy"
    admin_username = "cdis"
    admin_password = "zacr0cks!K"
  }
}

resource "azurerm_postgresql_server" "userapi" {
  name = "userapi-db"
  resource_group_name = "${var.azure_resource_group_name}"
  location = "${var.azure_region}"
  sku {
    name = "PGSQLB50"
    capacity = 50
    tier = "Basic"
  }
  administrator_login = "userapi_user"
  administrator_login_password = "${var.db_password_userapi}"
  version = "9.6"
  storage_mb = "51200"
  ssl_enforcement = "Enabled"
}

resource "azurerm_postgresql_server" "gdcapi" {
  name = "gdbapi-db"
  resource_group_name = "${var.azure_resource_group_name}"
  location = "${var.azure_region}"
  sku {
    name = "PGSQLB50"
    capacity = 50
    tier = "Basic"
  }
  administrator_login = "gdcapi_user"
  administrator_login_password = "${var.db_password_gdcapi}"
  version = "9.6"
  storage_mb = "51200"
  ssl_enforcement = "Enabled"
}

resource "azurerm_postgresql_server" "indexd" {
  name = "indexd-db"
  resource_group_name = "${var.azure_resource_group_name}"
  location = "${var.azure_region}"
  sku {
    name = "PGSQLB50"
    capacity = 50
    tier = "Basic"
  }
  administrator_login = "indexd_user"
  administrator_login_password = "${var.db_password_indexd}"
  version = "9.6"
  storage_mb = "51200"
  ssl_enforcement = "Enabled"
}

resource "azurerm_postgresql_firewall_rule" "userapi" {
  name = "userapi-rule"
  resource_group_name = "${var.azure_resource_group_name}"
  server_name = "${azurerm_postgresql_server.userapi.name}"
  start_ip_address = "172.16.0.0"
  end_ip_address = "172.16.255.255"
}

resource "azurerm_postgresql_firewall_rule" "gdcapi" {
  name = "gdcapi-rule"
  resource_group_name = "${var.azure_resource_group_name}"
  server_name = "${azurerm_postgresql_server.gdcapi.name}"
  start_ip_address = "172.16.0.0"
  end_ip_address = "172.16.255.255"
}

resource "azurerm_postgresql_firewall_rule" "indexd" {
  name = "indexd-rule"
  resource_group_name = "${var.azure_resource_group_name}"
  server_name = "${azurerm_postgresql_server.indexd.name}"
  start_ip_address = "172.16.0.0"
  end_ip_address = "172.16.255.255"
}

data "template_file" "kube_up" {
    template = "${file("../configs/kube-up.sh")}"
    vars {
        vpc_name = "${var.vpc_name}"
        s3_bucket = "${var.kube_bucket}"
    }
}

data "template_file" "configmap" {
    template = "${file("../configs/00configmap.yaml")}"
    vars {
        vpc_name = "${var.vpc_name}"
        hostname = "${var.hostname}"
    }
}

data "template_file" "kube_services" {
    template = "${file("../configs/kube-services.sh")}"
    vars {
        vpc_name = "${var.vpc_name}"
        s3_bucket = "${var.kube_bucket}"
    }
}

data "template_file" "reverse_proxy" {
    template = "${file("../configs/api_reverse_proxy.conf")}"
    vars {
        hostname = "${var.hostname}"
    }
}

data "template_file" "reverse_proxy_setup" {
    template = "${file("../configs/revproxy-setup.sh")}"
    vars {
        hostname = "${var.hostname}"
    }
}

data "template_file" "creds" {
    template = "${file("../configs/creds.tpl")}"
    vars {
        userapi_host = "${azurerm_postgresql_server.userapi.fqdn}"
        userapi_user = "${azurerm_postgresql_server.userapi.administrator_login}"
        userapi_pwd = "${azurerm_postgresql_server.userapi.administrator_login_password}"
        userapi_db = "${azurerm_postgresql_server.userapi.name}"
        gdcapi_host = "${azurerm_postgresql_server.gdcapi.fqdn}"
        gdcapi_user = "${azurerm_postgresql_server.gdcapi.administrator_login}"
        gdcapi_pwd = "${azurerm_postgresql_server.gdcapi.administrator_login_password}"
        gdcapi_db = "${azurerm_postgresql_server.gdcapi.name}"
        indexd_host = "${azurerm_postgresql_server.indexd.fqdn}"
        indexd_user = "${azurerm_postgresql_server.indexd.administrator_login}"
        indexd_pwd = "${azurerm_postgresql_server.indexd.administrator_login_password}"
        indexd_db = "${azurerm_postgresql_server.indexd.name}"
        hostname = "${var.hostname}"
        google_client_secret = "${var.google_client_secret}"
        google_client_id = "${var.google_client_id}"
        hmac_encryption_key = "${var.hmac_encryption_key}"
        gdcapi_indexd_password = "${var.gdcapi_indexd_password}"
    }
}

resource "null_resource" "config_setup" {
    provisioner "local-exec" {
        command = "mkdir ${var.vpc_name}_output; echo '${data.template_file.creds.rendered}' >${var.vpc_name}_output/creds.json"
    }

    provisioner "local-exec" {
        command = "echo \"${data.template_file.kube_up.rendered}\" > ${var.vpc_name}_output/kube-up.sh"
    }
    provisioner "local-exec" {
        command = "echo \"${data.template_file.kube_services.rendered}\" > ${var.vpc_name}_output/kube-services.sh"
    }
    provisioner "local-exec" {
        command = "echo \"${data.template_file.configmap.rendered}\" > ${var.vpc_name}_output/00configmap.yaml"
    }
    provisioner "local-exec" {
        command = "echo '${data.template_file.reverse_proxy.rendered}' > ${var.vpc_name}_output/proxy.conf"
    }
    provisioner "local-exec" {
        command = "echo '${data.template_file.reverse_proxy_setup.rendered}' > ${var.vpc_name}_output/revproxy-setup.sh"
    }

}
