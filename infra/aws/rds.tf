resource "aws_security_group" "rds_access" {
  name   = "rds-access-from-lambda"
  vpc_id = module.vpc.vpc_id

  ingress {
    description     = "Postgres from Lambda"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

module "db" {
  source = "terraform-aws-modules/rds/aws"

  identifier = var.db_user_info.db_name

  engine            = "postgres"
  engine_version    = "17"
  instance_class    = "db.t3.micro"
  allocated_storage = 5

  db_name                     = var.db_user_info.db_name
  username                    = var.db_user_info.username
  password                    = var.db_user_info.password
  manage_master_user_password = false
  port                        = "5432"

  iam_database_authentication_enabled = true

  vpc_security_group_ids = [
    aws_security_group.rds_access.id
  ]

  availability_zone = var.aws_azs[0]

  create_db_subnet_group = true
  subnet_ids             = module.vpc.private_subnets

  # DB parameter group
  family = "postgres17"

  # DB option group
  major_engine_version = "17"

  # Database Deletion Protection
  deletion_protection      = false
  delete_automated_backups = true
  skip_final_snapshot      = true
}

resource "aws_iam_role" "rds_proxy_role" {
  name = "rds-proxy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "rds_proxy_secrets_access" {
  name = "rds-proxy-secrets-access"
  role = aws_iam_role.rds_proxy_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.db_secret.arn
      }
    ]
  })
}

resource "aws_db_proxy" "rds_proxy" {
  name                   = "${var.db_user_info.db_name}-proxy"
  engine_family          = "POSTGRESQL"
  role_arn               = aws_iam_role.rds_proxy_role.arn
  vpc_subnet_ids         = module.vpc.private_subnets
  vpc_security_group_ids = [aws_security_group.rds_access.id]

  auth {
    auth_scheme = "SECRETS"
    secret_arn  = aws_secretsmanager_secret.db_secret.arn
    iam_auth    = "DISABLED"
  }

  require_tls = true
}

resource "aws_db_proxy_target" "proxy_target" {
  db_proxy_name          = aws_db_proxy.rds_proxy.name
  target_group_name      = "default"
  db_instance_identifier = module.db.db_instance_identifier
  depends_on             = [aws_db_proxy.rds_proxy, module.db]
}
