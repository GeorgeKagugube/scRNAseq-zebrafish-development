#!/usr/bin/env python3
import argparse
import csv
import os
from pathlib import Path
from typing import Dict, Tuple

def read_samplesheet(samplesheet: Path) -> Dict[str, str]:
    """
    Returns dict mapping sample_id -> srr_accession.
    Requires columns: sample_id, srr_accession
    """
    with samplesheet.open() as f:
        reader = csv.DictReader(f, delimiter="\t")
        required = {"sample_id", "srr_accession"}
        if reader.fieldnames is None or not required.issubset(set(reader.fieldnames)):
            raise ValueError(f"samplesheet must contain columns: {sorted(required)}")
        mapping = {}
        for row in reader:
            sample = row["sample_id"].strip()
            srr = row["srr_accession"].strip()
            if not sample or not srr:
                continue
            mapping[sample] = srr
    if not mapping:
        raise ValueError("No sample_id/srr_accession rows found in samplesheet.")
    return mapping

def link_or_move(src: Path, dst: Path, mode: str) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.exists() or dst.is_symlink():
        dst.unlink()
    if mode == "symlink":
        dst.symlink_to(src.resolve())
    elif mode == "move":
        src.rename(dst)
    else:
        raise ValueError("mode must be 'symlink' or 'move'")

def main():
    ap = argparse.ArgumentParser(
        description="Rename SRA split FASTQs into Cell Ranger naming convention "
                    "(using mapping _1->I1, _2->R1, _3->R2)."
    )
    ap.add_argument("--samplesheet", required=True, type=Path, help="TSV with sample_id and srr_accession")
    ap.add_argument("--fastq_dir", required=True, type=Path, help="Directory containing SRR_* fastq.gz files")
    ap.add_argument("--out_dir", required=True, type=Path, help="Output directory for Cell Ranger-formatted FASTQs")
    ap.add_argument("--lane", default="L001", help="Lane label (default: L001)")
    ap.add_argument("--sample_suffix", default="S1", help="Sample suffix (default: S1)")
    ap.add_argument("--mode", choices=["symlink", "move"], default="symlink",
                    help="symlink (recommended) or move (destructive, matches in-place renaming)")
    args = ap.parse_args()

    mapping = read_samplesheet(args.samplesheet)

    # Validate input dir
    if not args.fastq_dir.exists():
        raise FileNotFoundError(f"fastq_dir not found: {args.fastq_dir}")

    args.out_dir.mkdir(parents=True, exist_ok=True)

    missing_any = False

    for sample_id, srr in mapping.items():
        # Expected inputs from fasterq-dump --split-files + gzip
        f1 = args.fastq_dir / f"{srr}_1.fastq.gz"
        f2 = args.fastq_dir / f"{srr}_2.fastq.gz"
        f3 = args.fastq_dir / f"{srr}_3.fastq.gz"  # optional

        if not f1.exists() or not f2.exists():
            print(f"[ERROR] Missing required FASTQs for {sample_id} ({srr}): "
                  f"{f1.name if not f1.exists() else ''} {f2.name if not f2.exists() else ''}".strip())
            missing_any = True
            continue

        # Your mapping: _1->I1, _2->R1, _3->R2
        out_i1 = args.out_dir / f"{sample_id}_{args.sample_suffix}_{args.lane}_I1_001.fastq.gz"
        out_r1 = args.out_dir / f"{sample_id}_{args.sample_suffix}_{args.lane}_R1_001.fastq.gz"
        out_r2 = args.out_dir / f"{sample_id}_{args.sample_suffix}_{args.lane}_R2_001.fastq.gz"

        link_or_move(f1, out_i1, args.mode)
        link_or_move(f2, out_r1, args.mode)

        if f3.exists():
            link_or_move(f3, out_r2, args.mode)
        else:
            # Cell Ranger can proceed without I1 for some datasets; here, R2 is required for gene expression.
            # If _3 is missing, fail hard because your mapping expects _3 to be R2.
            print(f"[ERROR] Missing expected R2 file for {sample_id} ({srr}): {f3.name}")
            missing_any = True

        print(f"[INFO] {sample_id} ({srr}) -> "
              f"{out_i1.name}, {out_r1.name}, {out_r2.name}")

    if missing_any:
        raise SystemExit(1)

if __name__ == "__main__":
    main()

