#!/usr/bin/bash -l

## State the number of cores 
#$ -pe mpi 5

## Request for the number of threads
#$ -pe smp 8

## State the amount of RAM per core
#$ -l mem=10G

## Select the run time
#$ -l h_rt=24:00:00

## Request 50 gigabyte of TMPDIR 
#$ -l tmpfs=50G

## Specify the working directory here
#$ -cwd 

## Load the modules that are required for teh alignment here 
module unload gcc-libs
module load sra-tools/3.0.6/gnu-10.2.0


## Running the snakemake workflow instead
## Activate the conda environment here 
#conda activate /home/uczrgwk/.conda/envs/sklearn-env

## grant execution rights and then run the script
# 0) Make SRR list file (optional if you are driving via samplesheet)
cut -f2 config/samplesheet.tsv | tail -n +2 > config/srr_used.txt

# 1) Download SRAs
bash scripts/00_fetch_srr.sh config/srr_used.txt work/sra

# 2) Convert to FASTQ
bash scripts/01_fastq_dump.sh config/srr_used.txt work/sra work/fastq/raw 8

# 3) Rename (symlink recommended)
python scripts/02_rename_for_cellranger.py --samplesheet config/samplesheet.tsv \
  --fastq_dir work/fastq/raw --out_dir work/fastq/cellranger --mode symlink

# 4) Count
bash scripts/03_cellranger_count.sh config/samplesheet.tsv work/fastq/cellranger \
  work/reference/cellranger_ref work/cellranger 16 64

# 5) Aggr
bash scripts/04_cellranger_aggr.sh config/samplesheet.tsv work/cellranger \
  config/cellranger_aggr.csv work/cellranger 16 64 mapped

