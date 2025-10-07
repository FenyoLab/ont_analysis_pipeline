#!/bin/bash
#SBATCH --partition=cpu_short
#SBATCH --job-name=log_errors
#SBATCH --mem=1Gb
#SBATCH --time=0-12:00:00
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --nodes=1
#SBATCH --output=/gpfs/data/broshr01lab/logs/run_error_%j.log

module load samtools/1.20

SOURCE=$1
RUN_ID=$2
REFERENCE_ID=$3

echo "ERROR PROCESSING: ${SOURCE} ${RUN_ID} ${REFERENCE_ID}"
