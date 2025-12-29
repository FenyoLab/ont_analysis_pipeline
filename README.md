# ont_analysis_pipeline

## Overview

A lightweight SLURM-based pipeline of shell scripts for Oxford Nanopore Technologies (ONT) data processing. The repository contains a set of sbatch scripts and helper shell scripts to perform basecalling, demultiplexing, alignment, merging, bigWig generation, structural variant calling, and cleanup across one or many samples.

## Key features

- Modular steps implemented as numbered sbatch scripts (1..9) so individual stages can be run or re-run independently.
- Designed to run on HPC clusters using SLURM and common ONT tools (Dorado, minimap2, samtools, etc.).
- Simple submit wrappers to run the full pipeline or only per-sample stages.

## Prerequisites

- A SLURM scheduler and an HPC environment.
- ONT tools: Dorado (or preferred basecaller), guppy/dorado demuxing toolchain where appropriate.
- Standard bioinformatics tools: samtools, minimap2, bedtools, deeptools (for bigWig), and any structural variant callers used in your environment.
- Bash (>=4), basic GNU coreutils, and any site-specific modules loaded on the cluster.

## Repository layout

- 1_copy_from_grid.sbatch - step for copying raw data from grid storage
- 2_dorado_basecall.sbatch - basecalling (Dorado)
- 3_dorado_demux.sbatch - demultiplexing
- 4_samtools_merge_barcode.sbatch - merge per-barcode BAMs
- 5_dorado_align.sbatch - alignment (e.g. minimap2)
- 6_create_bigwig.sbatch - create bigWig coverage tracks
- 6_1_create_bigwig_no_targets.sbatch - variant of bigWig creation
- 7_cleanup.sbatch - cleanup temporary files
- 8_build_registry.sbatch - build summary/registry of runs
- 9_structural_variant_calling.sbatch - structural variant calling step
- submit.sh, submit_first_steps.sh, submit_per_sample_only.sh - convenience wrappers
- print_links.sh, dm_test.sbatch, error.sbatch - helpers and test scripts

## Configuration and inputs

- The scripts assume a directory layout and data locations set by environment variables or by editing the top of each sbatch script.
- Inputs are typically raw ONT output (pod5, a reference FASTA and an Adaptive Sampling bed file), a sample sheet or barcode map for demultiplexing, and a reference genome for alignment.
- Edit resource requests (time, memory, CPUs, partitions) in each sbatch script to match the cluster policy.

## Basic usage

1. Prepare data on the cluster and update any path variables in the step scripts.
2. Create a file called `variables.conf` which contains the following paths and parameters:
   ```sh
   # Directory that will contain raw POD5 data and references
   # Data is stored in <year>/<run_id>/ format
   RAW_DATA_DIR=/path/to/raw_data
   # Directory that contains processed data outputs
   # Data is stored in <year>/<run_id>/ format
   PROCESSED_DATA=/path/to/processed_data_directory
   # Directory containing links to the directory containing reference genomes and adaptive sampling bed files
   # The reference genome directory is stored alongside the raw data in <year>/<run_id>/ format
   REFERENCE_LINKS=/path/to/reference_links
   # Directory to store dorado basecallign models
   MODELS_DIR=/path/to/models_dir
   # Per species annotations such as repeat masker and ncbi gene tracks
   ANNOTATIONS_DIR=/path/to/annotations_dir
   ```
3. Run the pipeline from the repository root:
   - To submit the whole pipeline in order, use: ./submit.sh

   ```
    sh submit.sh \
          <remote_data_dir> \
          <run_id> \
          <species> \
          -r <reference_directory> <reference_link_name> <adaptive_sampling_bed> \
          -o <barcode_id> <sample_id> <sample_name> <reference_fasta> \
          -o <barcode_id> <sample_id> <sample_name> <reference_fasta>
   ```

   - remote_data_dir: Path to the raw data directory on the sequencer (e.g. /data/raw_data)
   - run_id: date of the run or a unique identifier (yyyymmdda)
   - species: used to fetch the correct annotation from the ANNOTATIONS_DIR
   - -r reference information
     - reference_directory: directory name listed in the remote_data_dir
     - reference_link_name: symlink name in REFERENCE_LINKS pointing to the reference genome directory
     - adaptive_sampling_bed: bed file for adaptive sampling regions
   - -o sample specific details (repeatable for multiple samples)
     - barcode_id: barcode identifier (e.g. 01)
     - sample_id: unique sample identifier (ONT00001)
     - sample_name: human-readable sample name
     - reference_fasta: path to the reference FASTA for alignment
   - To run initial steps only: ./submit_first_steps.sh
   - To submit per-sample processing: ./submit_per_sample_only.sh

4. Monitor SLURM jobs with squeue and check produced logs in the working directories.

## Outputs

- Per-sample and merged BAMs, coverage bigWig files, structural variant VCFs/beds, and run-level registry/summary files.
- Logs for each sbatch job are written to the working directories configured in the scripts.

## Extending or customizing

- To add new processing steps, follow the numeric naming convention (e.g., 10_new_step.sbatch) and update the submit wrapper if needed.
- Replace tools or change arguments inside the sbatch scripts; keep resource requests and IO patterns consistent with cluster norms.

## Troubleshooting

- Check SLURM job logs and stdout/stderr files for errors.
- Ensure required tools are available in your PATH or loaded as modules in the sbatch script header.
- For permission or IO errors, verify cluster storage mounts and user access.

## Contact / Further help

For questions about this pipeline, create an issue ticket. Adapt the scripts to local conventions before production use.
