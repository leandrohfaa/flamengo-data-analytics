variable "project_name" {
  description = "Nome do projeto, usado em nomes e tags dos recursos"
  type        = string
  default     = "flamengo-data-analytics"
}

variable "region" {
  description = "Região AWS"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Ambiente de execução"
  type        = string
  default     = "dev"
}

variable "athena_scan_limit_bytes" {
  description = "Limite de dados escaneados por consulta no Athena (proteção de custo)"
  type        = number
  default     = 104857600 # 100 MB
}
