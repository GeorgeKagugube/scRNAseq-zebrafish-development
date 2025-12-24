#!/usr/bin -l
# this script was run on UCL's Myriad HPC to download files from the NCBI SRA database
# The shebang line above can be modified accordingly to suit the users HPC or local environment
# Usage:
#   bash scripts/00_fetch_srr.sh config/srr_used_d5_d8.txt work/sra
#
# Input: text file with one SRR accession per line
# Output: work/sra/<SRR>/<SRR>.sra

SRR_LIST="${1:-config/srr_used_d5_d8.txt}"
OUTDIR="${2:-work/sra}"

if [[ ! -f "${SRR_LIST}" ]]; then
  echo "[ERROR] SRR list not found: ${SRR_LIST}" >&2
  exit 1
fi

mkdir -p "${OUTDIR}"

# Optional: reduce accidental blank lines / comments
grep -vE '^\s*$|^\s*#' "${SRR_LIST}" | while read -r SRR; do
  echo "[INFO] Prefetching ${SRR}"
  mkdir -p "${OUTDIR}/${SRR}"
  # Write directly to desired path
  prefetch "${SRR}" --output-file "${OUTDIR}/${SRR}/${SRR}.sra"
done

echo "[INFO] Done. SRA files in: ${OUTDIR}/<SRR>/<SRR>.sra"

