# --- 1. PROVIDER & VARIABLES ---
provider "aws" {
  region = "us-east-1"
}

variable "vpc_id"          { default = "vpc-0123456789abcdef0" }
variable "public_subnets"  { default = ["subnet-111", "subnet-222"] }
variable "private_subnets" { default = ["subnet-333", "subnet-444"] }

# --- 2. SECURITY & EDGE (WAF + LB) ---
resource "aws_wafv2_web_acl" "global_waf" {
  name     = "uber-scale-waf"
  scope    = "REGIONAL"
  
  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "uberScaleWaf"
    sampled_requests_enabled   = true
  }
}

resource "aws_lb" "ingress_lb" {
  name               = "uber-ingress-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ingress_sg.id]
  subnets            = var.public_subnets
}

# --- 3. REAL-TIME PIPELINES (KAFKA) ---
resource "aws_kms_key" "kafka_key" { 
  description = "Encryption key for Kafka" 
}

resource "aws_msk_cluster" "event_pipeline" {
  cluster_name           = "uber-kafka-pipeline"
  kafka_version          = "3.2.0"
  number_of_broker_nodes = 3

  broker_node_group_info {
    instance_type   = "kafka.m5.xlarge"
    client_subnets  = var.private_subnets
    security_groups = [aws_security_group.kafka_sg.id]
  }

  encryption_info {
    encryption_at_rest_kms_key_arn = aws_kms_key.kafka_key.arn
  }
}

# --- 4. GEOSPATIAL & STATE (REDIS + DYNAMODB) ---
resource "aws_elasticache_replication_group" "geo_index" {
  replication_group_id = "uber-geo-index"
  description          = "Redis for Geo-sharding driver positions" # Changed name
  node_type            = "cache.m6g.large"
  num_cache_clusters   = 3 # Note: If this fails, change to 'number_cache_clusters'
  engine               = "redis"
  engine_version       = "7.0"
  port                 = 6379
  parameter_group_name = "default.redis7"
}

resource "aws_dynamodb_table" "trip_store" {
  name         = "UberTrips"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "TripID" # You can keep this; the warning is just a suggestion for newer versions
  range_key    = "UserID"

  attribute {
    name = "TripID"
    type = "S"
  }
  
    attribute {
        name = "UserID"
        type = "S"
    }
    }

resource "aws_eks_cluster" "matching_engine" {
  name     = "uber-matching-engine"
  role_arn = aws_iam_role.eks_role.arn

  vpc_config {
    subnet_ids = var.private_subnets
  }
}

resource "aws_eks_node_group" "matching_workers" {
  cluster_name    = aws_eks_cluster.matching_engine.name
  node_group_name = "matching-nodes"
  node_role_arn   = aws_iam_role.node_role.arn
  subnet_ids      = var.private_subnets

  scaling_config {
    desired_size = 10
    max_size     = 50
    min_size     = 5
  }

  instance_types = ["c6i.2xlarge"] 
}

resource "aws_db_instance" "financial_db" {
  identifier          = "uber-finance-db"
  engine              = "postgres"
  instance_class      = "db.r6g.large"
  allocated_storage   = 100
  multi_az            = true
  password            = "ReplaceWithSecureSecret123!" 
  username            = "uber_admin"
  skip_final_snapshot = true
}

resource "aws_s3_bucket" "data_lake" {
  bucket = "uber-data-lake-analytics-storage"
}

resource "aws_security_group" "ingress_sg" {
  name   = "uber-ingress-sg"
  vpc_id = var.vpc_id
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "kafka_sg" {
  name   = "uber-kafka-sg"
  vpc_id = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "eks_role" {
  name = "uber-eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "eks.amazonaws.com" } }]
  })
}

resource "aws_iam_role" "node_role" {
  name = "uber-eks-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" } }]
  })
}