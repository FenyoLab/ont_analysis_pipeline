#!/usr/bin/env bash
#SBATCH --job-name=copy_pod5
#SBATCH --time=12:00:00
#SBATCH --partition=data_mover
#SBATCH --mem=16G
#SBATCH --nodes=1
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=4

set -euo pipefail

source ${JOB_VARIABLES}

echo "Command: $0 $@"

# Check if the correct number of arguments were provided.
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <source_directory> <destination_directory>"
    echo "Example: $0 /path/on/remote/ /path/on/hpc/"
    exit 1
fi

if [[ "$1" != /data/* ]]; then
    echo "ERROR: Source directory must start with '/data/' for safety."
    exit 1
fi

