#!/bin/bash
#SBATCH --partition=a100_short
#SBATCH --job-name=basecall
#SBATCH --mem=64Gb
#SBATCH --time=0-12:00:00
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=32
#SBATCH --nodes=1
#SBATCH --output=/gpfs/data/broshr01lab/logs/basecall_%j.log
#SBATCH --gres=gpu:2

set -e

module load dorado/1.0.0

POD_INPUT=$1
OUTPUT=$2
OUTPUT_DIR=$(dirname "${OUTPUT}")

echo "OUTPUT: ${OUTPUT}"
echo "OUTPUT_DIR: ${OUTPUT_DIR}"
if [ ! -d "$OUTPUT_DIR" ]; then
  mkdir -p "$OUTPUT_DIR"
fi

start_time=$(date +%s)
echo "Arguments: ${POD_INPUT} ${OUTPUT}"
echo "Job properties: ${SLURM_CPUS_PER_TASK} ${SLURM_GPUS_ON_NODE} ${SLURM_NODELIST}"
dorado basecaller -r sup $POD_INPUT --kit-name SQK-NBD114-24 > $OUTPUT


end_time=$(date +%s)
execution_time_minutes=$((end_time-start_time))
echo "Script execution time: $execution_time_minutes seconds"
