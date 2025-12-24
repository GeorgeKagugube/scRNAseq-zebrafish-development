#!/usr/bin -l
set -euo pipefail

# Usage:
#   bash scripts/01_fastq_dump.sh config/srr_used_d5_d8.txt work/sra work/fastq/raw 8 you 
#
# Input:
#   - SRR list file (one SRR per line)
#   - SRA directory produced by 00_fetch_srr.sh (work/sra/<SRR>/<SRR>.sra)
# Output:
#   - work/fastq/raw/<SRR>_<1|2|3>.fastq.gz

SRR_LIST="${1:-config/srr_used_d5_d8.txt}"
SRA_DIR="${2:-work/sra}"
FASTQ_OUT="${3:-work/fastq/raw}"
THREADS="${4:-8}"

if [[ ! -f "${SRR_LIST}" ]]; 
	then
  		echo "[ERROR] SRR list not found: ${SRR_LIST}" >&2
  	exit 1
fi

mkdir -p "${FASTQ_OUT}"

grep -vE '^\s*$|^\s*#' "${SRR_LIST}" | while read -r SRR; do
  SRA_FILE="${SRA_DIR}/${SRR}/${SRR}.sra"
  if [[ ! -f "${SRA_FILE}" ]]; then
    echo "[ERROR] Missing SRA file: ${SRA_FILE}" >&2
    exit 1
  fi

  echo "[INFO] fasterq-dump ${SRR} -> ${FASTQ_OUT}"
  fasterq-dump --split-files --threads "${THREADS}" --outdir "${FASTQ_OUT}" "${SRA_FILE}"

  echo "[INFO] gzip ${SRR} FASTQs"
  # pigz if present, else gzip
  if command -v pigz >/dev/null 2>&1; then
    pigz -p "${THREADS}" -f "${FASTQ_OUT}/${SRR}"_*.fastq
  else
    gzip -f "${FASTQ_OUT}/${SRR}"_*.fastq
  fi

  # sanity check
  if [[ ! -f "${FASTQ_OUT}/${SRR}_1.fastq.gz" ]] || [[ ! -f "${FASTQ_OUT}/${SRR}_2.fastq.gz" ]]; then
    echo "[ERROR] Expected ${SRR}_1.fastq.gz and ${SRR}_2.fastq.gz not found in ${FASTQ_OUT}" >&2
    exit 1
  fi
done

echo "[INFO] Done. FASTQs in: ${FASTQ_OUT}"

