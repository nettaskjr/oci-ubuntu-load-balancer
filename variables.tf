variable "tenancy_ocid" {
  description = "OCID da sua Tenancy na OCI. Usado para encontrar as imagens públicas do sistema operacional."
}

variable "user_ocid" {
  description = "OCID do seu usuário na OCI."
}

variable "fingerprint" {
  description = "Fingerprint da sua chave de API."
}

variable "region" {
  description = "Região da OCI onde os recursos serão criados."
}

# variable "compartment_ocid" {
#   description = "OCID do compartimento onde os recursos serão criados."
# }

variable "ssh_public_key_path" {
  description = "Caminho para o arquivo da sua chave pública SSH."
}

variable "api_private_key_path" {
  description = "Caminho para o arquivo da sua chave privada da API."
}

variable "user_instance" {
  description = "Nome de usuário para a instância."
  default     = "ubuntu"
}

variable "instance_display_name" {
  description = "Nome de exibição para a instância."
  default     = "ubuntu-instance"
}

variable "instance_shape" {
  description = "Forma da instância. Considere VM.Standard.E2.1.Micro ou VM.Standard.A1.Flex, caso queira usar a opção Always Free."
  default     = "VM.Standard.A1.Flex"
}

variable "instance_ocpus" {
  description = "Número de OCPUs para a instância (relevante para formas Flex)."
  default     = 2
}

variable "instance_memory_in_gbs" {
  description = "Memória em GBs para a instância (relevante para formas Flex)."
  default     = 12
}

variable "boot_volume_size_in_gbs" {
  description = "Tamanho do volume de inicialização em GBs."
  default     = 50
}

variable "email" {
  description = "E-mail do usuário para notificações."
}