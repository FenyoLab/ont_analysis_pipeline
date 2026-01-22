#!/usr/bin/env bash
#SBATCH --job-name=cleanup
#SBATCH --time=12:00:00
#SBATCH --partition=data_mover
#SBATCH --mem=32G
#SBATCH --nodes=1
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=4

set -euo pipefail

echo "Command: $0 $@"

# Check if the correct number of arguments were provided.
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <source_directory> <destination_directory> <run variables>"
    echo "Example: $0 /path/on/remote/ /path/on/bp/"
    exit 1
fi

# This checks if the first argument does NOT start with "/data/".
if [[ "$1" != /data/* ]]; then
    echo "ERROR: Source directory must start with '/data/' for safety."
    exit 1
fi

# Remote server details
REMOTE_SHORTCUT="grid"

# Directory paths
# Process arguments to ensure they have a trailing slash
SOURCE_DIR_RAW="$1"
DEST_DIR_RAW="$2"
JOB_VARIABLES="$3"

source ${JOB_VARIABLES}
SOURCE_DIR="${SOURCE_DIR_RAW%/}/"
DEST_DIR="${DEST_DIR_RAW%/}/"

CHECKSUM_FILE="checksums.md5"

echo "Step 1: Verifying file integrity on the HPC cluster..."
cd ${DEST_DIR}

if md5sum -c ${CHECKSUM_FILE}; then
    # If checksums match, the 'md5sum -c' command will exit with code 0 (success)
    echo "SUCCESS: Verification complete. All files were copied correctly."

    # Step 4: Delete files on the remote server
    # -------------------------------------------
    echo "Step 2: Deleting original files from remote server: ${REMOTE_SHORTCUT}"
    # SAFETY CHECK: Ensure the variable is not empty or a dangerous root path.
    if [[ -n "${SOURCE_DIR_RAW}" && "${SOURCE_DIR_RAW}" != "/" ]]; then
        # This command deletes the entire directory provided as the first argument.
        echo "ATTEMPTING TO rm -rf ${SOURCE_DIR_RAW}"
        ssh ${REMOTE_SHORTCUT} "rm -rf '${SOURCE_DIR_RAW}'"
        echo "Remote source directory deleted."
    else
        echo "DANGER: Source path variable was empty or '/'. Deletion skipped for safety."
        exit 1
    fi

else
    # If checksums do NOT match, 'md5sum -c' will exit with a non-zero code, and the script will stop.
    echo "ERROR: Verification failed! Checksum mismatch detected."
    echo "Source files on ${REMOTE_SHORTCUT} have NOT been deleted."
    exit 1 # Exit with an error code
fi

echo "Process finished successfully."
