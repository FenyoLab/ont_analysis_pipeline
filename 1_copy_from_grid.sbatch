#!/usr/bin/env bash
#SBATCH --job-name=copy_pod5
#SBATCH --time=12:00:00
#SBATCH --partition=data_mover
#SBATCH --mem=32G
#SBATCH --nodes=1
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=4
#SBATCH --output=/gpfs/data/broshr01lab/logs/copy_pod5_%x_%j.log

set -euo pipefail

# Check if the correct number of arguments were provided.
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <source_directory> <destination_directory>"
    echo "Example: $0 /path/on/remote/ /path/on/hpc/"
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
SOURCE_DIR="${SOURCE_DIR_RAW%/}/"
DEST_DIR="${DEST_DIR_RAW%/}/"

# Name for the checksum file
CHECKSUM_FILE="checksums.md5"

# --- Script Logic ---

echo "Starting the transfer process..."
echo "Source:      ${SOURCE_DIR}"
echo "Destination: ${DEST_DIR}"
echo "--------------------------------------------------------"

echo "Ensuring destination directory exists..."
mkdir -p "${DEST_DIR}"

# Step 1: Generate checksums on the remote server
# ------------------------------------------------
echo "Step 1: Generating checksums on the remote server: ${REMOTE_SHORTCUT}"
ssh ${REMOTE_SHORTCUT} "cd ${SOURCE_DIR} && find . -type f -exec md5sum {} +" > ${DEST_DIR}${CHECKSUM_FILE}
echo "Checksum manifest created."


# Step 2: Copy files from remote to local using rsync
# ----------------------------------------------------
echo "Step 2: Copying files with rsync..."
rsync -avP --exclude '${CHECKSUM_FILE}' ${REMOTE_SHORTCUT}:${SOURCE_DIR} ${DEST_DIR}
echo "rsync copy complete."

cd ${DEST_DIR}

if md5sum -c --quiet ${CHECKSUM_FILE}; then
    # If checksums match, the 'md5sum -c' command will exit with code 0 (success)
    echo "SUCCESS: Verification complete. All files were copied correctly."
else
    # If checksums do NOT match, 'md5sum -c' will exit with a non-zero code, and the script will stop.
    echo "ERROR: Verification failed! Checksum mismatch detected."
    echo "Source files on ${REMOTE_SHORTCUT} were not copied correctly."
    exit 1 # Exit with an error code
fi

echo "Process finished successfully."
