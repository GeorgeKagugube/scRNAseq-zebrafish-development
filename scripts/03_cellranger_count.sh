#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   bash scripts/03_cellranger_count.sh config/samplesheet.tsv work/fastq/cellranger work/reference/cellranger_ref work/cellranger 16 64
#
# Inputs:
#   - samplesheet.tsv: sample_id, srr_accession (others optional)
#   - FASTQ_DIR: directory containing Cell Ranger-named FASTQs
#   - TRANSCRIPTOME: Cell Ranger reference (mkref output dir)
# Outputs:
#   - work/cellranger/count/<sample_id>/outs/...

SAMPLESHEET="${1:-config/samplesheet.tsv}"
FASTQ_DIR="${2:-work/fastq/cellranger}"
TRANSCRIPTOME="${3:-work/reference/cellranger_ref}"
OUTDIR="${4:-work/cellranger}"
CORES="${5:-16}"
MEM="${6:-64}"

if [[ ! -f "${SAMPLESHEET}" ]]; then
  echo "[ERROR] samplesheet not found: ${SAMPLESHEET}" >&2
  exit 1
fi
if [[ ! -d "${FASTQ_DIR}" ]]; then
  echo "[ERROR] FASTQ_DIR not found: ${FASTQ_DIR}" >&2
  exit 1
fi
if [[ ! -d "${TRANSCRIPTOME}" ]]; then
  echo "[ERROR] TRANSCRIPTOME not found: ${TRANSCRIPTOME}" >&2
  exit 1
fi

mkdir -p "${OUTDIR}/count"

# Read TSV header indices
SAMPLE_COL=$(head -n 1 "${SAMPLESHEET}" | tr '\t' '\n' | nl -ba | awk '$2=="sample_id"{print $1}')
if [[ -z "${SAMPLE_COL}" ]]; then
  echo "[ERROR] samplesheet must contain a 'sample_id' column" >&2
  exit 1
fi

tail -n +2 "${SAMPLESHEET}" | while IFS=$'\t' read -r -a FIELDS; do
  SAMPLE_ID="${FIELDS[$((SAMPLE_COL-1))]}"
  [[ -z "${SAMPLE_ID}" ]] && continue

  echo "[INFO] cellranger count: ${SAMPLE_ID}"

  TMPDIR="work/tmp_cellranger/${SAMPLE_ID}"
  rm -rf "${TMPDIR}"
  mkdir -p "${TMPDIR}"
  pushd "${TMPDIR}" >/dev/null

  cellranger count \
    --id="${SAMPLE_ID}" \
    --transcriptome="${TRANSCRIPTOME}" \
    --fastqs="${FASTQ_DIR}" \
    --sample="${SAMPLE_ID}" \
    --localcores="${CORES}" \
    --localmem="${MEM}"

  popd >/dev/null

  rm -rf "${OUTDIR}/count/${SAMPLE_ID}"
  mv "${TMPDIR}/${SAMPLE_ID}" "${OUTDIR}/count/${SAMPLE_ID}"
done

echo "[INFO] Done. Cell Ranger count outputs in ${OUTDIR}/count/"

