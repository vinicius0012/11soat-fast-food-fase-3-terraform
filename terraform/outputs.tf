output "vpc_id" {
  value = module.vpc.vpc_id
}
output "eks_cluster_name" {
  value = module.eks.cluster_name
}
output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}
output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}
output "api_gateway_invoke_url" {
  value = aws_apigatewayv2_stage.http.invoke_url
}
output "lambda_function_name" {
  value = aws_lambda_function.cpf_auth.function_name
}
output "github_actions_role_arn" {
  value = aws_iam_role.github_actions_deploy_role.arn
}
output "private_subnet_ids" {
  value = module.vpc.private_subnets
}
