# =============================================================================
# ARO Cluster Outputs
# =============================================================================

output "cluster_id" {
  description = "The ARO cluster resource ID"
  value       = azurerm_redhat_openshift_cluster.aro.id
}

output "cluster_name" {
  description = "The name of the ARO cluster"
  value       = azurerm_redhat_openshift_cluster.aro.name
}

output "console_url" {
  description = "The OpenShift web console URL"
  value       = azurerm_redhat_openshift_cluster.aro.console_url
}

output "api_server_url" {
  description = "The API server URL"
  value       = azurerm_redhat_openshift_cluster.aro.api_server_profile[0].url
}

output "api_server_ip" {
  description = "The API server IP address"
  value       = azurerm_redhat_openshift_cluster.aro.api_server_profile[0].ip_address
}

output "ingress_ip" {
  description = "The ingress IP address"
  value       = azurerm_redhat_openshift_cluster.aro.ingress_profile[0].ip_address
}

output "vnet_id" {
  description = "The ID of the VNet used by the cluster"
  value       = local.vnet_id
}

output "master_subnet_id" {
  description = "The ID of the master subnet"
  value       = local.master_subnet_id
}

output "worker_subnet_id" {
  description = "The ID of the worker subnet"
  value       = local.worker_subnet_id
}

output "udr_route_table_id" {
  description = "The ID of the UDR route table (if enabled)"
  value       = local.effective_route_table_id
}
