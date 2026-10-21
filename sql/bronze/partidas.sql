CREATE EXTERNAL TABLE IF NOT EXISTS flamengo_bronze.partidas (
  id                  string,
  rodata              string,
  data                string,
  hora                string,
  mandante            string,
  visitante           string,
  formacao_mandante   string,
  formacao_visitante  string,
  tecnico_mandante    string,
  tecnico_visitante   string,
  vencedor            string,
  arena               string,
  mandante_placar     string,
  visitante_placar    string,
  mandante_estado     string,
  visitante_estado    string
)
PARTITIONED BY (data_carga string)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES ('separatorChar' = ',', 'quoteChar' = '"')
LOCATION 's3://flamengo-data-analytics-lake-384567542038/bronze/brasileirao/partidas/'
TBLPROPERTIES ('skip.header.line.count' = '1');

-- Registra as partições (data_carga=...) já existentes no S3
MSCK REPAIR TABLE flamengo_bronze.partidas;

-- Validação: partidas por ano civil
SELECT substr(data, 7, 4) AS ano, count(*) AS partidas
FROM flamengo_bronze.partidas
GROUP BY 1
ORDER BY 1;
