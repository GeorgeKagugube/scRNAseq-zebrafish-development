#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   bash scripts/04_cellranger_aggr.sh config/samplesheet.tsv work/cellranger work/cellranger/aggr_csv.csv work/cellranger 16 64 mapped
#
# Inputs:
#   - samplesheet.tsv (sample_id required)
#   - work/cellranger/count/<sample>/outs/molecule_info.h5
# Outputs:
#   - work/cellranger/aggr_all/outs/filtered_feature_bc_matrix.h5 (etc.)

SAMPLESHEET="${1:-config/samplesheet.tsv}"
CR_BASE="${2:-work/cellranger}"
AGGR_CSV="${3:-config/cellranger_aggr.csv}"
OUTDIR="${4:-work/cellranger}"
CORES="${5:-16}"
MEM="${6:-64}"
NORM="${7:-mapped}"   # mapped | none

if [[ ! -f "${SAMPLESHEET}" ]]; then
  echo "[ERROR] samplesheet not found: ${SAMPLESHEET}" >&2
  exit 1
fi
if [[ ! -d "${CR_BASE}/count" ]]; then
  echo "[ERROR] expected Cell Ranger count dir not found: ${CR_BASE}/count" >&2
  exit 1
fi

mkdir -p "$(dirname "${AGGR_CSV}")"

# Identify sample_id column
SAMPLE_COL=$(head -n 1 "${SAMPLESHEET}" | tr '\t' '\n' | nl -ba | awk '$2=="sample_id"{print $1}')
if [[ -z "${SAMPLE_COL}" ]]; then
  echo "[ERROR] samplesheet must contain a 'sample_id' column" >&2
  exit 1
fi

echo "sample_id,molecule_h5" > "${AGGR_CSV}"

tail -n +2 "${SAMPLESHEET}" | while IFS=$'\t' read -r -a FIELDS; do
  SAMPLE_ID="${FIELDS[$((SAMPLE_COL-1))]}"
  [[ -z "${SAMPLE_ID}" ]] && continue

  H5="${CR_BASE}/count/${SAMPLE_ID}/outs/molecule_info.h5"
  if [[ ! -f "${H5}" ]]; then
    echo "[ERROR] Missing molecule_info.h5 for ${SAMPLE_ID}: ${H5}" >&2
    exit 1
  fi
  echo "${SAMPLE_ID},${H5}" >> "${AGGR_CSV}"
done

echo "[INFO] Wrote aggr CSV: ${AGGR_CSV}"
echo "[INFO] Running cellranger aggr"

TMPDIR="work/tmp_cellranger/aggr_all"
rm -rf "${TMPDIR}"
mkdir -p "${TMPDIR}"
pushd "${TMPDIR}" >/dev/null

cellranger aggr \
  --id="aggr_all" \
  --csv="${AGGR_CSV}" \
  --normalize="${NORM}" \
  --localcores="${CORES}" \
  --localmem="${MEM}"

popd >/dev/null

rm -rf "${OUTDIR}/aggr_all"
mv "${TMPDIR}/aggr_all" "${OUTDIR}/aggr_all"

echo "[INFO] Done. Aggregated output in: ${OUTDIR}/aggr_all/outs/"

