variable "project_name" {
  description = "Nome base do projeto (prefixo de recursos)."
  type        = string
}
variable "aws_region" {
  description = "Região AWS."
  type        = string
  default     = "sa-east-1"
}
variable "eks_version" {
  description = "Versão do EKS."
  type        = string
  default     = "1.29"
}
variable "github_org" {
  description = "Organização/usuário do GitHub para OIDC."
  type        = string
}
variable "github_repo" {
  description = "Nome do repositório (sem org) para OIDC."
  type        = string
}
variable "lambda_s3_key" {
  description = "Chave (path) do artefato ZIP da Lambda."
  type        = string
  default     = "lambda-function.zip"
}
variable "lambda_handler" {
  description = "Handler da Lambda (ex: dist/handler.handler)."
  type        = string
  default     = "index.handler"
}
variable "lambda_runtime" {
  description = "Runtime da Lambda."
  type        = string
  default     = "nodejs20.x"
}
variable "allowed_cidrs_to_lb" {
  description = "CIDRs com acesso externo (ex: 0.0.0.0/0)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
