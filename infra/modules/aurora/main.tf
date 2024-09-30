
resource "aws_rds_cluster" "this" {
  engine                              = "aurora-postgresql"
  cluster_identifier                  = var.cluster_identifier
  cluster_identifier_prefix           = var.cluster_identifier_prefix
  master_username                     = "master"
  manage_master_user_password         = true
  iam_database_authentication_enabled = true
  skip_final_snapshot                 = true
  availability_zones                  = var.availability_zones
  enable_http_endpoint                = true
  db_subnet_group_name                = aws_db_subnet_group.this.name
  vpc_security_group_ids              = [aws_security_group.this.id]

  serverlessv2_scaling_configuration {
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity
  }
}

resource "aws_db_subnet_group" "this" {
  name_prefix = var.cluster_identifier_prefix
  name        = var.cluster_identifier
  subnet_ids  = var.subnet_ids
}

resource "aws_security_group" "this" {
  vpc_id = var.vpc_id
}

resource "aws_security_group_rule" "ingress" {
  type                     = "ingress"
  from_port                = aws_rds_cluster.this.port
  to_port                  = aws_rds_cluster.this.port
  protocol                 = "-1"
  security_group_id        = aws_security_group.this.id
  source_security_group_id = aws_security_group.client.id
}

resource "aws_security_group" "client" {
  vpc_id = var.vpc_id
}

resource "aws_secretsmanager_secret_rotation" "rotate_master_user_secret" {
  secret_id = local.master_user_secret_arn
  rotation_rules {
    automatically_after_days = 30
  }
}

resource "aws_iam_policy" "get_master_user_secret_value" {
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue",
        ],
        Resource = local.master_user_secret_arn
      },
    ],
  })
}

resource "aws_rds_cluster_instance" "this" {
  count              = var.instance_count
  cluster_identifier = aws_rds_cluster.this.id
  engine             = aws_rds_cluster.this.engine
  engine_version     = aws_rds_cluster.this.engine_version
  instance_class     = "db.serverless"
}

resource "aws_iam_role" "proxy" {
  name = "proxy"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "rds.amazonaws.com",
        },
      }
    ],
  })
}

resource "aws_iam_role_policy_attachment" "proxy" {
  role       = aws_iam_role.proxy.name
  policy_arn = aws_iam_policy.get_master_user_secret_value.arn
}


/*resource "aws_db_proxy" "this" {
  name          = "proxy"
  engine_family = "POSTGRESQL"
  role_arn      = aws_iam_role.proxy.arn
  auth {
    auth_scheme               = "SECRETS"
    client_password_auth_type = "POSTGRES_SCRAM_SHA_256"
    iam_auth                  = "DISABLED"
    secret_arn                = local.master_user_secret_arn
  }
  require_tls    = true
  vpc_subnet_ids = data.aws_db_subnet_group.default.subnet_ids
}

resource "aws_db_proxy_default_target_group" "this" {
  db_proxy_name = aws_db_proxy.this.name
}

resource "aws_db_proxy_target" "this" {
  db_proxy_name         = aws_db_proxy.this.name
  target_group_name     = aws_db_proxy_default_target_group.this.name
  db_cluster_identifier = aws_rds_cluster.this.cluster_identifier
}*/
