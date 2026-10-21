data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id

  # Nomes de bucket são globais na AWS; o ID da conta garante unicidade
  # sem precisar deixar o ID fixo no código público
  buckets = {
    data_lake      = "${var.project_name}-lake-${local.account_id}"
    athena_results = "${var.project_name}-athena-${local.account_id}"
  }

  layers = ["bronze", "silver", "gold"]
}

# ---------------------------------------------------------------------------
# S3: data lake (bronze/silver/gold como prefixos) e resultados do Athena
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "this" {
  for_each = local.buckets

  bucket        = each.value
  force_destroy = true # permite terraform destroy mesmo com arquivos (projeto de portfólio)
}

resource "aws_s3_bucket_public_access_block" "this" {
  for_each = aws_s3_bucket.this

  bucket                  = each.value.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = aws_s3_bucket.this

  bucket = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Resultados de consulta do Athena são temporários: apagar após 7 dias
resource "aws_s3_bucket_lifecycle_configuration" "athena_results" {
  bucket = aws_s3_bucket.this["athena_results"].id

  rule {
    id     = "expirar-resultados-athena"
    status = "Enabled"

    filter {}

    expiration {
      days = 7
    }
  }
}

# ---------------------------------------------------------------------------
# Glue Data Catalog: um database por camada do medalhão
# ---------------------------------------------------------------------------
resource "aws_glue_catalog_database" "layers" {
  for_each = toset(local.layers)

  name        = "flamengo_${each.key}"
  description = "Camada ${each.key} do data lake do projeto ${var.project_name}"
}

# ---------------------------------------------------------------------------
# Athena: workgroup com local de resultados e limite de custo por consulta
# ---------------------------------------------------------------------------
resource "aws_athena_workgroup" "this" {
  name          = var.project_name
  force_destroy = true

  configuration {
    enforce_workgroup_configuration = false
    bytes_scanned_cutoff_per_query  = var.athena_scan_limit_bytes

    result_configuration {
      output_location = "s3://${aws_s3_bucket.this["athena_results"].bucket}/results/"

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }
}
