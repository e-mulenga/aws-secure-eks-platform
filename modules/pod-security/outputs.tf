output "namespace_names" {
  value = [for ns in kubernetes_namespace.application : ns.metadata[0].name]
}

output "namespace_ids" {
  value = { for k, ns in kubernetes_namespace.application : k => ns.id }
}