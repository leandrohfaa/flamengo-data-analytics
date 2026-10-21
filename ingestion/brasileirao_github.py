import argparse
import hashlib
import json
import logging
import os
import sys
import time
from datetime import datetime, timezone

import requests

SOURCE_REPO = "adaoduque/Brasileirao_Dataset"
SOURCE_REF = "master"  # para reprodutibilidade total, troque por um commit SHA
BASE_URL = f"https://raw.githubusercontent.com/{SOURCE_REPO}/{SOURCE_REF}"

# nome da tabela no data lake -> arquivo na fonte
FILES = {
    "partidas": "campeonato-brasileiro-full.csv",
    "estatisticas": "campeonato-brasileiro-estatisticas-full.csv",
    "gols": "campeonato-brasileiro-gols.csv",
    "cartoes": "campeonato-brasileiro-cartoes.csv",
}

S3_PREFIX = "bronze/brasileirao"
MAX_RETRIES = 3

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
)
log = logging.getLogger("ingestao_brasileirao")


def download(url: str) -> bytes:
    """Baixa um arquivo com retry e backoff exponencial."""
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            resp = requests.get(url, timeout=60)
            resp.raise_for_status()
            return resp.content
        except requests.RequestException as exc:
            if attempt == MAX_RETRIES:
                raise
            wait = 2 ** attempt
            log.warning("Falha ao baixar (%s). Tentativa %d/%d, aguardando %ds",
                        exc, attempt, MAX_RETRIES, wait)
            time.sleep(wait)
    raise RuntimeError("inalcançável")


def basic_checks(table: str, content: bytes) -> int:
    """Validações mínimas da bronze: arquivo não vazio e com cabeçalho."""
    text = content.decode("utf-8")
    lines = [line for line in text.splitlines() if line.strip()]
    if len(lines) < 2:
        raise ValueError(f"{table}: arquivo vazio ou sem linhas de dados")
    if '"ID"' not in lines[0] and "partida_id" not in lines[0]:
        log.warning("%s: cabeçalho inesperado: %s", table, lines[0][:120])
    return len(lines) - 1  # linhas de dados, sem o cabeçalho


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--dry-run", action="store_true",
                        help="baixa e valida os arquivos sem enviar ao S3")
    args = parser.parse_args()

    bucket = os.environ.get("DATA_LAKE_BUCKET")
    if not args.dry_run and not bucket:
        log.error("Defina a variável de ambiente DATA_LAKE_BUCKET")
        return 1

    s3 = None
    if not args.dry_run:
        import boto3
        s3 = boto3.client("s3")

    load_ts = datetime.now(timezone.utc)
    load_date = load_ts.strftime("%Y-%m-%d")
    manifest = {
        "fonte": f"https://github.com/{SOURCE_REPO}",
        "ref": SOURCE_REF,
        "data_carga": load_date,
        "executado_em": load_ts.isoformat(),
        "arquivos": [],
    }

    for table, filename in FILES.items():
        url = f"{BASE_URL}/{filename}"
        log.info("Baixando %s", url)
        content = download(url)
        rows = basic_checks(table, content)
        sha256 = hashlib.sha256(content).hexdigest()

        # Mesma data de carga -> mesma chave: reexecutar no mesmo dia sobrescreve (idempotente)
        key = f"{S3_PREFIX}/{table}/data_carga={load_date}/{filename}"
        entry = {"tabela": table, "arquivo": filename, "linhas": rows,
                 "bytes": len(content), "sha256": sha256, "s3_key": key}
        manifest["arquivos"].append(entry)

        if args.dry_run:
            log.info("[dry-run] %s: %d linhas, %d bytes", table, rows, len(content))
            continue

        s3.put_object(
            Bucket=bucket,
            Key=key,
            Body=content,
            ContentType="text/csv",
            Metadata={"sha256": sha256, "source-url": url},
        )
        log.info("Enviado s3://%s/%s (%d linhas)", bucket, key, rows)

    manifest_json = json.dumps(manifest, ensure_ascii=False, indent=2)
    if args.dry_run:
        print(manifest_json)
    else:
        manifest_key = f"{S3_PREFIX}/_manifests/data_carga={load_date}/manifest.json"
        s3.put_object(Bucket=bucket, Key=manifest_key,
                      Body=manifest_json.encode("utf-8"),
                      ContentType="application/json")
        log.info("Manifesto gravado em s3://%s/%s", bucket, manifest_key)

    log.info("Ingestão concluída: %d arquivos", len(FILES))
    return 0


if __name__ == "__main__":
    sys.exit(main())
