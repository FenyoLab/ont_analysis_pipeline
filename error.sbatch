#!/bin/bash
#SBATCH --partition=cpu_short
#SBATCH --job-name=log_errors
#SBATCH --mem=1Gb
#SBATCH --time=0-12:00:00
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --nodes=1
#SBATCH --output=/gpfs/data/broshr01lab/logs/run_error_%j.log

set -euo pipefail

source ${JOB_VARIABLES}

SOURCE=$1
RUN_ID=$2
REFERENCE_ID=$3

echo "ERROR PROCESSING: ${SOURCE} ${RUN_ID} ${REFERENCE_ID}"

echo "ENV VARS"
echo "RAW_DATA=${RAW_DATA}"
echo "PROCESSED_DATA=${PROCESSED_DATA}"
echo "RAW_DESTINATION=${RAW_DESTINATION}"
echo "REFERENCE_LINKS=${REFERENCE_LINKS}"
echo "RMSK_BED=${RMSK_BED}"
echo "PROCESSED_DATA_DIR=${PROCESSED_DATA_DIR}"
echo "PROCESSED_BAM=${PROCESSED_BAM}"
echo "DEMUX_DIR=${DEMUX_DIR}"
echo "JOB_VARIABLES=${JOB_VARIABLES}"
