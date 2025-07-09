# Configuração do provedor OCI
provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.api_private_key_path
  region           = var.region
}

# Busca os Domínios de Disponibilidade (ADs) na região especificada
data "oci_identity_availability_domains" "ads" {
  # Usa o OCID da tenancy para buscar os ADs, pois eles são um recurso no nível da tenancy.
  compartment_id = var.compartment_ocid
}

# Busca a imagem mais recente do Ubuntu compatível
data "oci_core_images" "latest_ubuntu_image" {
  compartment_id           = var.compartment_ocid # Imagens públicas estão no compartimento da tenancy
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04" # Você pode ajustar a versão majoritária desejada
  shape                    = var.instance_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# Definição da Virtual Cloud Network (VCN)
resource "oci_core_vcn" "always_free_vcn" {
  compartment_id = var.compartment_ocid
  cidr_block     = "10.0.0.0/16"
  display_name   = "AlwaysFreeVCN"
  dns_label      = "alwaysfreevcn"
}

# Definição do Internet Gateway
resource "oci_core_internet_gateway" "internet_gateway" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.always_free_vcn.id
  display_name   = "InternetGateway"
}

# Definição da Tabela de Rotas
resource "oci_core_route_table" "route_table" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.always_free_vcn.id
  display_name   = "RouteTable"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.internet_gateway.id
  }
}

# Definição da Sub-rede Pública
resource "oci_core_subnet" "public_subnet" {
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.always_free_vcn.id
  cidr_block        = "10.0.1.0/24"
  display_name      = "PublicSubnet"
  dns_label         = "public"
  route_table_id    = oci_core_route_table.route_table.id
  security_list_ids = [oci_core_security_list.default_security_list.id]
}

# Definição da Security List
resource "oci_core_security_list" "default_security_list" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.always_free_vcn.id
  display_name   = "DefaultSecurityList"

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }

  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      max = 22
      min = 22
    }
  }

  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      max = 80
      min = 80
    }
  }

  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      max = 443
      min = 443
    }
  }
}

# Definição do Load Balancer
resource "oci_load_balancer_load_balancer" "always_free_lb" {
  compartment_id = var.compartment_ocid
  display_name   = "AlwaysFreeLB"
  shape          = "flexible"
  shape_details {
    maximum_bandwidth_in_mbps = 10
    minimum_bandwidth_in_mbps = 10
  }
  is_private = false
  subnet_ids = [oci_core_subnet.public_subnet.id]
}

# Definição do Backend Set do Load Balancer
resource "oci_load_balancer_backend_set" "lb_backend_set" {
  health_checker {
    port        = "80"
    protocol    = "HTTP"
    return_code = 200
    url_path    = "/"
  }
  load_balancer_id = oci_load_balancer_load_balancer.always_free_lb.id
  name             = "lb-backend-set"
  policy           = "ROUND_ROBIN"
}

# Definição do Listener HTTP
resource "oci_load_balancer_listener" "http_listener" {
  default_backend_set_name = oci_load_balancer_backend_set.lb_backend_set.name
  load_balancer_id         = oci_load_balancer_load_balancer.always_free_lb.id
  name                     = "http_listener"
  port                     = 80
  protocol                 = "HTTP"
}

# Definição do Listener HTTPS
resource "oci_load_balancer_listener" "https_listener" {
  default_backend_set_name = oci_load_balancer_backend_set.lb_backend_set.name
  load_balancer_id         = oci_load_balancer_load_balancer.always_free_lb.id
  name                     = "https_listener"
  port                     = 443
  protocol                 = "HTTP"
  # A configuração de SSL deve ser adicionada aqui.
}

# Definição das Instâncias de Computação
resource "oci_core_instance" "always_free_vm" {
  count = 2
  # Distribui as instâncias de forma cíclica entre os ADs disponíveis na região.
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[count.index % length(data.oci_identity_availability_domains.ads.availability_domains)].name
  compartment_id      = var.compartment_ocid
  display_name        = "AlwaysFree-VM-${count.index}"
  shape               = var.instance_shape

  shape_config {
    memory_in_gbs = var.instance_memory_in_gbs
    ocpus         = var.instance_ocpus
  }

  create_vnic_details {
    assign_public_ip = true # Necessário para o provisioner remote-exec, pode ser false ao usar user_data se não precisar de acesso direto.
    subnet_id        = oci_core_subnet.public_subnet.id
  }

  metadata = {
    ssh_authorized_keys = file(var.ssh_public_key_path)
    user_data           = base64encode(file("${path.module}/cloud-init.sh"))
  }

  source_details {
    # Usa o ID da imagem mais recente encontrada pelo data source
    source_id   = data.oci_core_images.latest_ubuntu_image.images[0].id
    source_type = "image"
  }
}

# Adicionando as instâncias ao Backend Set
resource "oci_load_balancer_backend" "lb_backend" {
  count            = 2
  backendset_name  = oci_load_balancer_backend_set.lb_backend_set.name
  ip_address       = oci_core_instance.always_free_vm[count.index].private_ip
  load_balancer_id = oci_load_balancer_load_balancer.always_free_lb.id
  port             = 80
}