locals {
  name = var.project_name
  tags = {
    Project = var.project_name
    Stack   = "infra-app-aws"
    Owner   = "team"
  }
}

# ---------------- VPC ----------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = "${local.name}-vpc"
  cidr = "10.50.0.0/16"

  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  private_subnets = ["10.50.1.0/24", "10.50.2.0/24"]
  public_subnets  = ["10.50.101.0/24", "10.50.102.0/24"]

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway   = true
  single_nat_gateway   = true

  tags = local.tags
}

# ---------------- S3 Bucket para Lambda ----------------
resource "aws_s3_bucket" "lambda_artifacts" {
  bucket = "${local.name}-lambda-artifacts-${random_id.bucket_suffix.hex}"
  tags   = local.tags
}

resource "aws_s3_bucket_versioning" "lambda_artifacts" {
  bucket = aws_s3_bucket.lambda_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "lambda_artifacts" {
  bucket = aws_s3_bucket.lambda_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# ---------------- ECR ----------------
resource "aws_ecr_repository" "app" {
  name                 = "${local.name}-app"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration { scan_on_push = true }
  tags = local.tags
}

# ---------------- EKS ----------------
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "${local.name}-eks"
  cluster_version = var.eks_version

  cluster_endpoint_public_access = true

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets

  enable_irsa = true

  eks_managed_node_group_defaults = {
    instance_types = ["t3.medium"]
  }

  eks_managed_node_groups = {
    default = {
      min_size     = 1
      max_size     = 3
      desired_size = 1
    }
  }

  tags = local.tags
}

# ---------------- OIDC p/ GitHub Actions ----------------
data "aws_iam_policy_document" "github_oidc" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [
        "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/*",
        "repo:${var.github_org}/${var.github_repo}:pull_request"
      ]
    }
  }
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

resource "aws_iam_role" "github_actions_deploy_role" {
  name               = "${local.name}-gha-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_oidc.json
  tags               = local.tags
}

# Permissões mínimas: ECR push/pull, EKS (describe), S3 (artefatos), Lambda update, APIGW
data "aws_iam_policy_document" "gha_permissions" {
  statement {
    sid     = "ECR"
    actions = ["ecr:GetAuthorizationToken", "ecr:BatchCheckLayerAvailability", "ecr:CompleteLayerUpload",
               "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage", "ecr:InitiateLayerUpload", "ecr:PutImage", "ecr:UploadLayerPart"]
    resources = ["*"]
  }
  statement {
    sid     = "EKS"
    actions = ["eks:DescribeCluster"]
    resources = [module.eks.cluster_arn]
  }
  statement {
    sid     = "S3Read"
    actions = ["s3:GetObject", "s3:ListBucket"]
    resources = ["*"]
  }
  statement {
    sid     = "LambdaUpdate"
    actions = ["lambda:UpdateFunctionCode", "lambda:PublishVersion", "lambda:UpdateFunctionConfiguration"]
    resources = ["*"]
  }
  statement {
    sid     = "APIGWManage"
    actions = ["apigateway:GET", "apigateway:POST", "apigateway:PATCH", "apigateway:PUT", "apigateway:DELETE",
               "execute-api:ManageConnections"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "gha_policy" {
  name   = "${local.name}-gha-policy"
  policy = data.aws_iam_policy_document.gha_permissions.json
}

resource "aws_iam_role_policy_attachment" "gha_attach" {
  role       = aws_iam_role.github_actions_deploy_role.name
  policy_arn = aws_iam_policy.gha_policy.arn
}

# ---------------- API Gateway + Lambda (consulta/autenticação CPF) - COMENTADO ----------------
# resource "aws_cloudwatch_log_group" "lambda_logs" {
#   name              = "/aws/lambda/${local.name}-cpf-auth"
#   retention_in_days = 14
#   tags              = local.tags
# }

# resource "aws_iam_role" "lambda_exec" {
#   name = "${local.name}-lambda-exec"
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Action = "sts:AssumeRole"
#       Effect = "Allow"
#       Principal = { Service = "lambda.amazonaws.com" }
#     }]
#   })
#   tags = local.tags
# }

# resource "aws_iam_role_policy_attachment" "lambda_logs_attach" {
#   role       = aws_iam_role.lambda_exec.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
# }

# # Criar um arquivo ZIP temporário para a Lambda
# data "archive_file" "lambda_zip" {
#   type        = "zip"
#   output_path = "/tmp/lambda-function.zip"
#   source {
#     content = <<EOF
# exports.handler = async (event) => {
#     console.log('Event:', JSON.stringify(event, null, 2));
    
#     return {
#         statusCode: 200,
#         headers: {
#             'Content-Type': 'application/json',
#             'Access-Control-Allow-Origin': '*',
#             'Access-Control-Allow-Headers': 'Content-Type',
#             'Access-Control-Allow-Methods': 'POST, OPTIONS'
#         },
#         body: JSON.stringify({
#             message: 'Lambda function is working!',
#             timestamp: new Date().toISOString(),
#             event: event
#         })
#     };
# };
# EOF
#     filename = "index.js"
#   }
# }

# # Upload do arquivo ZIP para o S3
# resource "aws_s3_object" "lambda_zip" {
#   bucket = aws_s3_bucket.lambda_artifacts.bucket
#   key    = "lambda-function.zip"
#   source = data.archive_file.lambda_zip.output_path
#   etag   = data.archive_file.lambda_zip.output_md5
# }

# resource "aws_lambda_function" "cpf_auth" {
#   function_name = "${local.name}-cpf-auth"
#   role          = aws_iam_role.lambda_exec.arn
#   handler       = "index.handler"
#   runtime       = "nodejs20.x"
#   s3_bucket     = aws_s3_bucket.lambda_artifacts.bucket
#   s3_key        = aws_s3_object.lambda_zip.key

#   environment {
#     variables = {
#       NODE_OPTIONS = "--enable-source-maps"
#     }
#   }

#   depends_on = [
#     aws_cloudwatch_log_group.lambda_logs,
#     aws_s3_object.lambda_zip
#   ]
#   tags = local.tags
# }

# resource "aws_apigatewayv2_api" "http" {
#   name          = "${local.name}-http-api"
#   protocol_type = "HTTP"
#   tags          = local.tags
# }

# resource "aws_apigatewayv2_integration" "lambda_integration" {
#   api_id                 = aws_apigatewayv2_api.http.id
#   integration_type       = "AWS_PROXY"
#   integration_method     = "POST"
#   integration_uri        = aws_lambda_function.cpf_auth.invoke_arn
#   payload_format_version = "2.0"
# }

# resource "aws_apigatewayv2_route" "post_cpf" {
#   api_id    = aws_apigatewayv2_api.http.id
#   route_key = "POST /cpf/auth"
#   target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
# }

# resource "aws_lambda_permission" "apigw_invoke" {
#   statement_id  = "AllowAPIGatewayInvoke"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.cpf_auth.function_name
#   principal     = "apigateway.amazonaws.com"
#   source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
# }

# resource "aws_apigatewayv2_stage" "http" {
#   api_id      = aws_apigatewayv2_api.http.id
#   name        = "$default"
#   auto_deploy = true
#   tags        = local.tags
# }

# ---------------- Security Groups (exemplo para Load Balancer público) ----------------
resource "aws_security_group" "alb_public" {
  name        = "${local.name}-alb-public"
  description = "Public access to EKS ingress/ALB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs_to_lb
  }
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs_to_lb
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}
