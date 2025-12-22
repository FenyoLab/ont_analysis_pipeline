#!/usr/bin/env bash
#SBATCH --partition=cpu_short
#SBATCH --job-name=merge
#SBATCH --mem=16Gb
#SBATCH --time=0-12:00:00
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=8
#SBATCH --nodes=1

set -euo pipefail

echo "Command: $0 $@"
echo "Job properties: ${SLURM_CPUS_PER_TASK} ${SLURM_NODELIST}"

module load samtools/1.20

SAMPLE_BAM=$1
BARCODE=$2

DEMUX_DIRECTORY=$3

JOB_VARIABLES="$4"
source ${JOB_VARIABLES}

start_time=$(date +%s)
echo "Arguments: ${SAMPLE_BAM} ${DEMUX_DIRECTORY} ${BARCODE}"

samtools cat -o "${SAMPLE_BAM}" $DEMUX_DIRECTORY/*barcode$BARCODE.bam

end_time=$(date +%s)
execution_time_minutes=$((end_time-start_time))
echo "Script execution time: $execution_time_minutes seconds"
