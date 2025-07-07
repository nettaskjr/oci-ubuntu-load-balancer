output "load_balancer_public_ip" {
  description = "Endereço IP público do Load Balancer."
  value       = oci_load_balancer_load_balancer.always_free_lb.ip_address_details[0].ip_address
}

output "instance_public_ips" {
  description = "Endereços IP públicos das instâncias de VM."
  value = {
    for instance in oci_core_instance.always_free_vm :
    instance.display_name => instance.public_ip
  }
}

output "latest_ubuntu_image_used" {
  description = "Informações sobre a imagem do Ubuntu que foi automaticamente selecionada e utilizada."
  value       = data.oci_core_images.latest_ubuntu_image.images[0]
}