output "data_lake_bucket" {
  description = "Bucket do data lake"
  value       = aws_s3_bucket.this["data_lake"].bucket
}

output "athena_results_bucket" {
  description = "Bucket de resultados do Athena"
  value       = aws_s3_bucket.this["athena_results"].bucket
}

output "glue_databases" {
  description = "Databases do Glue Data Catalog por camada"
  value       = { for k, db in aws_glue_catalog_database.layers : k => db.name }
}

output "athena_workgroup" {
  description = "Workgroup do Athena"
  value       = aws_athena_workgroup.this.name
}
