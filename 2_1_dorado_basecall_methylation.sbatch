#!/usr/bin/env bash
#SBATCH --partition=a100_short
#SBATCH --job-name=CG-basecall
#SBATCH --mem=128Gb
#SBATCH --time=3-00:00:00
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=32
#SBATCH --nodes=1
#SBATCH --gres=gpu:4
#SBATCH --mail-type=FAIL      # Mail events (NONE, BEGIN, END, FAIL, ALL)
#SBATCH --mail-user=mark.grivainis@nyulangone.org     # Where to send mail

module load dorado/1.2.0

set -euo pipefail

echo "Command: $0 $@"

POD_INPUT=$1
SKIP_BARCODES=$2
JOB_VARIABLES="$3"

source ${JOB_VARIABLES}

start_time=$(date +%s)
echo "Arguments: ${POD_INPUT}, ${SKIP_BARCODES}"
echo "Job properties: ${SLURM_CPUS_PER_TASK} ${SLURM_GPUS_ON_NODE} ${SLURM_NODELIST}"
if [ "$SKIP_BARCODES" -eq 1 ]; then
  dorado basecaller -r --models-directory $MODELS_DIR sup,5mCG_5hmCG $POD_INPUT > $BASECALLED_BAM
else
  dorado basecaller -r --models-directory $MODELS_DIR sup,5mCG_5hmCG $POD_INPUT --kit-name SQK-NBD114-24 > $BASECALLED_BAM
fi


end_time=$(date +%s)
execution_time_minutes=$((end_time-start_time))
echo "Script execution time: $execution_time_minutes seconds"
