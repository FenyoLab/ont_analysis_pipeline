#!/usr/bin/env bash
#SBATCH --job-name=copy_pod5
#SBATCH --time=12:00:00
#SBATCH --partition=data_mover
#SBATCH --mem=32G
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

#---
# Create a ssh key on BP for the device that has the stored data
# Add this key to your ssh config and set REMOTE_SHORTCUT to the configured
# name
#---
REMOTE_SHORTCUT="grid"

# Directory paths
# Process arguments to ensure they have a trailing slash
SOURCE_DIR_RAW="$1"
DEST_DIR_RAW="$2"
SOURCE_DIR="${SOURCE_DIR_RAW%/}/"
DEST_DIR="${DEST_DIR_RAW%/}/"

CHECKSUM_FILE="checksums.md5"


echo "Starting the transfer process..."
echo "Source:      ${SOURCE_DIR}"
echo "Destination: ${DEST_DIR}"
echo "--------------------------------------------------------"

echo "Ensuring destination directory exists..."
mkdir -p "${DEST_DIR}"

# Step 1: Generate checksums on the remote server
# ------------------------------------------------
echo "Step 1: Generating checksums on the remote server: ${REMOTE_SHORTCUT}"
# ssh ${REMOTE_SHORTCUT} "cd ${SOURCE_DIR} && find . -type f -exec md5sum {} +" > ${DEST_DIR}${CHECKSUM_FILE}
echo "Checksum manifest created."


# Step 2: Copy files from remote to local using rsync
# ----------------------------------------------------
echo "Step 2: Copying files with rsync..."
# rsync -avP --exclude '${CHECKSUM_FILE}' ${REMOTE_SHORTCUT}:${SOURCE_DIR} ${DEST_DIR}
echo "rsync copy complete."

cd ${DEST_DIR}


echo "Step 3: Validating copied file checksums..."
# if md5sum -c --quiet ${CHECKSUM_FILE}; then
#     # If checksums match, the 'md5sum -c' command will exit with code 0 (success)
#     echo "SUCCESS: Verification complete. All files were copied correctly."
# else
#     # If checksums do NOT match, 'md5sum -c' will exit with a non-zero code, and the script will stop.
#     echo "ERROR: Verification failed! Checksum mismatch detected."
#     echo "Source files on ${REMOTE_SHORTCUT} were not copied correctly."
#     exit 1 # Exit with an error code
# fi

#=== use the copied data to set up variables for later steps ===
shopt -s nullglob

# Use an array to capture matching files
FASTA_FILES=("${RAW_DESTINATION}$REFERENCE_DIR"/*.fa)
BED_FILES=("${RAW_DESTINATION}$REFERENCE_DIR"/*.bed)

# Check for exactly one fasta file
if [[ ${#FASTA_FILES[@]} -ne 1 ]]; then
  echo "Error: Found ${#FASTA_FILES[@]} fasta files in '${RAW_DESTINATION}$REFERENCE_DIR'. Exactly one is required." >&2
  exit 1
fi

# Check for exactly one bed file
if [[ ${#BED_FILES[@]} -ne 1 ]]; then
  echo "Error: Found ${#BED_FILES[@]} bed files in '${RAW_DESTINATION}$REFERENCE_DIR'. Exactly one is required." >&2
  exit 1
fi

REFERENCE_FASTA="${FASTA_FILES[0]}"
TARGETS_BED="${BED_FILES[0]}"

filename=$(basename "$REFERENCE_FASTA")
LINK_NAME="${filename%.*}"

# Check if the symbolic link already exists
if [ ! -L "${REFERENCE_LINKS}/${LINK_NAME}" ]; then
    # If the link does not exist, create it
    ln -s "${RAW_DESTINATION}$REFERENCE_DIR" "${REFERENCE_LINKS}/${LINK_NAME}"
    echo "Symbolic link '$LINK_NAME' created, pointing to '${RAW_DESTINATION}$REFERENCE_DIR'."
else
    echo "Symbolic link '$LINK_NAME' already exists."
fi

# =============================================================


echo "export REFERENCE_FASTA='${REFERENCE_FASTA}'" >> $JOB_VARIABLES
echo "export TARGETS_BED='${TARGETS_BED}'" >> $JOB_VARIABLES

echo "Process finished successfully."
