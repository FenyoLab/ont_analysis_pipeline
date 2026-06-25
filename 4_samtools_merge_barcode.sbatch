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

module load samtools/1.14

SKIP_BARCODES=$1
SAMPLE_BAM=$2
BARCODE=$3

DEMUX_DIRECTORY=$4

JOB_VARIABLES="$5"
source ${JOB_VARIABLES}

start_time=$(date +%s)
echo "Arguments: ${SAMPLE_BAM} ${DEMUX_DIRECTORY} ${BARCODE}"

if [ "$SKIP_BARCODES" -eq 1 ]; then
  cp $BASECALLED_BAM $SAMPLE_BAM
else
  samtools cat -o "${SAMPLE_BAM}" $DEMUX_DIRECTORY/*barcode$BARCODE.bam
fi


end_time=$(date +%s)
execution_time_minutes=$((end_time-start_time))
echo "Script execution time: $execution_time_minutes seconds"
