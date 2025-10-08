#!/usr/bin/env bash
#SBATCH --partition=cpu_short
#SBATCH --job-name=bigwig
#SBATCH --mem=32Gb
#SBATCH --time=0-12:00:00
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=32
#SBATCH --nodes=1

set -euo pipefail

source ${JOB_VARIABLES}

echo "Command: $0 $@"

module load python/cpu/3.10.6
unset PYTHONPATH

PROCESSED_DIR=$1
ANNOTATION_DIR=$2
OUTPUT_PATH=$3
SAMPLE_MAPPING=$4

/gpfs/data/broshr01lab/manual_scripts/igv_registry_builder/.venv/bin/build_registry $PROCESSED_DIR $ANNOTATION_DIR -o $OUTPUT_PATH --sample-mapping $SAMPLE_MAPPING
