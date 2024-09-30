
data "aws_rds_clusters" "prod" {
  filter {
    name = "tag:Environment"
    values = ["prod"]
  }
}

data "aws_rds_cluster" "prod" {
  cluster_identifier = data.aws_rds_clusters.prod.clusters.cluster_identifiers[0]
}

