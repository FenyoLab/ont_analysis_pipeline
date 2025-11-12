#!/usr/bin/env bash
#SBATCH --partition=cpu_short
#SBATCH --job-name=align
#SBATCH --mem=32Gb
#SBATCH --time=0-12:00:00
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=32
#SBATCH --nodes=1

set -euo pipefail

echo "Command: $0 $@"

module load dorado/1.0.0
module load samtools/1.20

BAM_INPUT=$1
JOB_VARIABLES="$2"

source ${JOB_VARIABLES}

# == FROM ENV VARS FILE CREATED BY submit.sh ==
FA_INPUT=${REFERENCE_FASTA}

BAM_OUTPUT="${BAM_INPUT%.*}".aligned.bam
SORTED_BAM_OUTPUT="${BAM_INPUT%.*}".aligned.sorted.bam


start_time=$(date +%s)
echo "Arguments: ${BAM_INPUT} ${FA_INPUT} ${BAM_OUTPUT}"
echo "Job properties: ${SLURM_CPUS_PER_TASK} ${SLURM_NODELIST}"
dorado aligner $FA_INPUT $BAM_INPUT > $BAM_OUTPUT
samtools sort -@ 32 $BAM_OUTPUT -o $SORTED_BAM_OUTPUT
samtools index -@ 32 -b $SORTED_BAM_OUTPUT $SORTED_BAM_OUTPUT.bai

end_time=$(date +%s)
execution_time_minutes=$((end_time-start_time))
echo "Script execution time: $execution_time_minutes seconds"
