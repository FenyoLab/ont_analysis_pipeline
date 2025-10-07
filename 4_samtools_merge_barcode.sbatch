#!/bin/bash
#SBATCH --partition=cpu_short
#SBATCH --job-name=demux
#SBATCH --mem=16Gb
#SBATCH --time=0-12:00:00
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=8
#SBATCH --nodes=1
#SBATCH --output=/gpfs/data/broshr01lab/logs/samtools_cat_%j.log

module load samtools/1.20

SAMPLE_BAM=$1
BARCODE=$2
DEMUX_DIRECTORY=$3

start_time=$(date +%s)
echo "Arguments: ${SAMPLE_BAM} ${DEMUX_DIRECTORY} ${BARCODE}"
echo "Job properties: ${SLURM_CPUS_PER_TASK} ${SLURM_NODELIST}"
samtools cat -o "${SAMPLE_BAM}" $DEMUX_DIRECTORY/*barcode$BARCODE.bam

end_time=$(date +%s)
execution_time_minutes=$((end_time-start_time))
echo "Script execution time: $execution_time_minutes seconds"
