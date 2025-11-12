#!/usr/bin/env bash
#SBATCH --partition=cpu_short
#SBATCH --job-name=sv_calling
#SBATCH --mem=32Gb
#SBATCH --time=0-12:00:00
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=16
#SBATCH --nodes=1

set -euo pipefail

# source ${JOB_VARIABLES}

echo "Command: $0 $@"

module load python/cpu/3.10.6
unset PYTHONPATH

usage() {
  echo "Usage: $0 <sorted_bam_file>"
  exit 1
}

if [[ $# -eq 0 ]]; then
        echo "Error: No arguments provided." >&2
        usage
fi

# Check if exactly two arguments are provided
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  usage
fi

if [[ $# -ne 2 ]]; then
  echo "Error: incorrect number of arguments provided"
  usage
fi

SORTED_BAM_FILE=$1
JOB_VARIABLES="$2"

VCF_FILENAME="${SORTED_BAM_FILE%.aligned.sorted.bam}".vcf.gz

echo $VCF_FILENAME

start_time=$(date +%s)
echo "Arguments: ${SORTED_BAM_FILE}"
echo "Job properties: ${SLURM_CPUS_PER_TASK} ${SLURM_NODELIST}"

# Step 1: Sniffles
echo "Step 1: Running Sniffles..."

/gpfs/data/broshr01lab/manual_scripts/ont_tools/.venv/bin/sniffles \
  --input ${SORTED_BAM_FILE} \
  --vcf ${VCF_FILENAME} \
  -t ${SLURM_CPUS_PER_TASK}

end_time=$(date +%s)
execution_time_minutes=$((end_time-start_time))
echo "Script execution time: $execution_time_minutes seconds"
