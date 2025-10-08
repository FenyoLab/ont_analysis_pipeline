#!/usr/bin/env bash
#SBATCH --partition=cpu_short
#SBATCH --job-name=demux
#SBATCH --mem=32Gb
#SBATCH --time=0-12:00:00
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=16
#SBATCH --nodes=1

set -euo pipefail

source ${JOB_VARIABLES}

echo "Command: $0 $@"

module load dorado/1.0.0

BAM_INPUT=$1
OUTPUT_DIR=$2



start_time=$(date +%s)
echo "Arguments: ${BAM_INPUT} ${OUTPUT_DIR}"
echo "Job properties: ${SLURM_CPUS_PER_TASK} ${SLURM_NODELIST}"
dorado demux --output-dir $OUTPUT_DIR --no-classify $BAM_INPUT


end_time=$(date +%s)
execution_time_minutes=$((end_time-start_time))
echo "Script execution time: $execution_time_minutes seconds"
