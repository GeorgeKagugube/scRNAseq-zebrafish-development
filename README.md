# Zebrafish brain scRNA-seq (SRA → Cell Ranger → Scanpy)
Reproducible workflow for processing 10x Genomics v2 zebrafish brain scRNA-seq from NCBI SRA and GEO, running Cell Ranger count/aggr on HPC, and downstream analysis in Python (Scanpy) on macOS.

## Data source and scope
- BioProject: **PRJNA664124**   
- GEO Series: **GSE158142** (“Emergence of neuronal diversity during vertebrate brain development”)  
- Example GEO Sample: **GSM4793216** = *zBr5dpf4_S1* (5 dpf brain)  
- Paper: Raj et al., 2020 (Neuron)}  

### Subset used in this repo
This repo focuses on **5 dpf** and **8 dpf** samples only (not all timepoints in the series). The GEO series includes multiple 5 dpf and 8 dpf samples (e.g., GSM4793213–GSM4793221 for 5 dpf; GSM4793222–GSM4793234 for 8 dpf). :contentReference[oaicite:5]{index=5}

### Reference
- Organism: *Danio rerio*
- Reference genome used: **GRCz10** (document exact FASTA/GTF sources + versions in `environment/cellranger_versions.md`)

---

## Pipeline overview
1. Download SRR runs from SRA (SRA Toolkit)
2. Split FASTQs and rename into Cell Ranger naming convention
3. Build Cell Ranger reference (GRCz10 FASTA + GTF)
4. Run `cellranger count` per run (HPC)
5. Aggregate with `cellranger aggr` (HPC)
6. Transfer aggregated output to Mac
7. Scanpy QC → normalization → HVGs → PCA/UMAP → clustering → markers/annotation

> Note: SRA Toolkit guidance and metadata download approaches are documented by NCBI; `fasterq-dump` is the recommended successor to `fastq-dump`.

---

## Figures (placeholders)
Add these images to `results/figures/` (or update paths below):

### Workflow diagram
![Pipeline diagram](results/figures/pipeline_diagram.png)

### QC summary
![QC violin plots](results/figures/qc_violin.png)

### Embedding colored by timepoint
![UMAP by timepoint](results/figures/umap_timepoint.png)

### Marker overview (dotplot / heatmap)
![Marker dotplot](results/figures/marker_dotplot.png)

---

## Repo structure
```text
.
├── config/
│   ├── project.yml
│   ├── srr_alt
│   ├── srr_used_d5_d8.txt
│   ├── samplesheet.tsv
│   └── cellranger_aggr.csv
├── scripts/
│   ├── 00_fetch_srr.sh
│   ├── 01_fastq_dump.sh
│   ├── 02_rename_for_cellranger.py
│   ├── 03_cellranger_count.sh
│   └── 04_cellranger_aggr.sh
├── environment/
│   ├── scanpy_env.yml
│   ├── cellranger_versions.md
│   └── sratoolkit_versions.md
├── notebooks/
├── src/
└── results/
    ├── figures/
    └── tables/

