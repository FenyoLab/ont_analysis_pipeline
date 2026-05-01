#!/usr/bin/env bash
#SBATCH --partition=cpu_short
#SBATCH --job-name=demux
#SBATCH --mem=32Gb
#SBATCH --time=0-12:00:00
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=16
#SBATCH --nodes=1

# This script should prepare the fasta file for downstream steps
#   1. Make a backup of the original
#   2. Sort the fasta in natural order and set the width to 80
#   3. Generate fai and chrom.sizes files
#   4. Compress the original fasta

set -euo pipefail

echo "Command: $0 $@"

module load seqkit/2.5.0
module load samtools/1.14

FASTA_INPUT=$1
JOB_VARIABLES=$2

source ${JOB_VARIABLES}

REFERENCE=${FASTA_INPUT}
CHROM_SIZES="${REFERENCE%.fa}".chrom.sizes
OG_FASTA="${REFERENCE}".original
OG_FASTA_XZ="${OG_FASTA}".xz

start_time=$(date +%s)
echo "Arguments: ${FASTA_INPUT}"
echo "Job properties: ${SLURM_CPUS_PER_TASK} ${SLURM_NODELIST}"

# If there is not a backup, make one
if [[ ! -f "$OG_FASTA" && ! -f $OG_FASTA_XZ ]]; then
  echo "Backing up to ${OG_FASTA}"
  mv $REFERENCE $OG_FASTA
fi

echo "Formatting fasta"
seqkit sort -j $SLURM_CPUS_PER_TASK --natural-order $OG_FASTA | seqkit seq -j $SLURM_CPUS_PER_TASK -w 80 > $REFERENCE


echo "Generating chromosome sizes file..."
samtools faidx "$REFERENCE"
cut -f1,2 "${REFERENCE}.fai" > "$CHROM_SIZES"


# Compress the original if there is not already a compressed version
if [[! -f $OG_FASTA_XZ ]]; then
  echo "Compressing ${OG_FASTA}"
  xz -T $SLURM_CPUS_PER_TASK ${OG_FASTA}
fi

end_time=$(date +%s)
execution_time_minutes=$((end_time-start_time))
echo "Script execution time: $execution_time_minutes seconds"
