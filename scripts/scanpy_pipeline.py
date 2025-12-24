#!/usr/bin/env python
import argparse
import pandas as pd
import scanpy as sc
import numpy as np

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--filtered_h5", required=True)
    ap.add_argument("--samplesheet", required=True)
    ap.add_argument("--out_adata", required=True)
    ap.add_argument("--qc_fig", required=True)
    ap.add_argument("--umap_fig", required=True)
    ap.add_argument("--marker_fig", required=True)

    ap.add_argument("--min_genes", type=int, default=200)
    ap.add_argument("--min_cells", type=int, default=3)
    ap.add_argument("--max_pct_mt", type=float, default=20.0)
    ap.add_argument("--n_top_genes", type=int, default=2000)
    ap.add_argument("--leiden_resolution", type=float, default=1.0)

    args = ap.parse_args()

    # Load aggregated matrix
    adata = sc.read_10x_h5(args.filtered_h5)
    adata.var_names_make_unique()

    # Attach sample metadata if barcodes carry sample prefixes from aggr
    meta = pd.read_csv(args.samplesheet, sep="\t", dtype=str)
    meta = meta.set_index("sample_id")

    # Cell Ranger aggr typically prefixes barcodes with sample_id (e.g., "sampleID_AAAC...")
    # We parse sample_id from obs_names up to first "-" or "_" depending on format.
    def infer_sample_id(bc: str):
        # Common: "sampleID_AAAC..." or "sampleID-AAAC..."
        if "_" in bc:
            return bc.split("_")[0]
        if "-" in bc:
            return bc.split("-")[0]
        return "UNKNOWN"

    adata.obs["sample_id"] = [infer_sample_id(x) for x in adata.obs_names]
    adata.obs = adata.obs.join(meta, on="sample_id")

    # Basic QC
    # Mito genes in zebrafish often start with "mt-" (case varies by annotation)
    adata.var["mt"] = adata.var_names.str.lower().str.startswith("mt-")
    sc.pp.calculate_qc_metrics(adata, qc_vars=["mt"], inplace=True)

    # Filter
    sc.pp.filter_cells(adata, min_genes=args.min_genes)
    sc.pp.filter_genes(adata, min_cells=args.min_cells)
    adata = adata[adata.obs.pct_counts_mt <= args.max_pct_mt].copy()

    # Normalize + HVGs + PCA/Neighbors/UMAP
    sc.pp.normalize_total(adata, target_sum=1e4)
    sc.pp.log1p(adata)
    sc.pp.highly_variable_genes(adata, n_top_genes=args.n_top_genes, subset=True)
    sc.pp.scale(adata, max_value=10)
    sc.tl.pca(adata)
    sc.pp.neighbors(adata)
    sc.tl.umap(adata)
    sc.tl.leiden(adata, resolution=args.leiden_resolution)

    # QC plot
    sc.pl.violin(
        adata,
        ["n_genes_by_counts", "total_counts", "pct_counts_mt"],
        jitter=0.4,
        multi_panel=True,
        save=False,
        show=False
    )
    # scanpy writes to default, so explicitly use matplotlib save
    import matplotlib.pyplot as plt
    plt.savefig(args.qc_fig, dpi=200, bbox_inches="tight")
    plt.close()

    # UMAP by timepoint if present
    color = "timepoint_dpf" if "timepoint_dpf" in adata.obs.columns else "leiden"
    sc.pl.umap(adata, color=[color, "leiden"], show=False)
    plt.savefig(args.umap_fig, dpi=200, bbox_inches="tight")
    plt.close()

    # Marker plot (basic; adjust later with curated markers)
    sc.tl.rank_genes_groups(adata, "leiden", method="wilcoxon")
    sc.pl.rank_genes_groups_dotplot(adata, n_genes=5, show=False)
    plt.savefig(args.marker_fig, dpi=200, bbox_inches="tight")
    plt.close()

    # Save
    adata.write(args.out_adata)

if __name__ == "__main__":
    main()

