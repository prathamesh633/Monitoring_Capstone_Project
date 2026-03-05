###############################################################################
# StorageClass for Kubernetes PersistentVolumes (used by Elasticsearch)
###############################################################################
resource "kubernetes_storage_class" "ebs_sc" {
  metadata {
    name = "ebs-sc"
  }
  storage_provisioner    = "ebs.csi.aws.com"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type      = "gp3"
    fsType    = "ext4"
    encrypted = "true"
  }

  depends_on = [
    aws_eks_addon.aws_ebs_csi_driver,
    aws_eks_node_group.main
  ]
}
