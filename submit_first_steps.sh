#!/usr/bin/env bash

set -euo pipefail

# Check if the correct number of arguments were provided.
if [ "$#" -le 6 ]; then
    echo "Usage: $0 <source_directory> <run_id> [-o <barcode> <sample_id> <sample_name> <reference_fasta_path> ...]"
    echo "Example: $0 /path/on/remote/ 202509 -o B6 ONT00001 Sample6"
    exit 1
fi

if [[ "$1" != /data/* ]]; then
    echo "ERROR: Source directory must start with '/data/' for safety."
    exit 1
fi

# -- Arguments
SOURCE="$1"
RUN_ID="$2"

shift 2

BARCODES=()
SAMPLE_IDS=()
SAMPLE_NAMES=()
REFERENCE_FASTAS=()


# Loop through the remaining arguments and store them in the array
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o)
      if [ "$#" -lt 5 ]; then
        echo "Error: -o requires a key and a value."
        exit 1
      fi
      BARCODES+=("$2")
      SAMPLE_IDS+=("$3")
      SAMPLE_NAMES+=("$4")
      REFERENCE_DIRS+=("$5")
      shift 5
      ;;
    *)
      echo "Error: Unknown argument: '$1'"
      exit 1
      ;;
  esac
done



# -- Source Variables
source ./variables.conf

echo "---Configured Paths---"
echo "RAW_DATA:         ${RAW_DATA}"
echo "PROCESSED_DATA:   ${PROCESSED_DATA}"
echo "REFERENCE_LINKS:  ${REFERENCE_LINKS}"
echo "RMSK_BED:         ${RMSK_BED}"
echo "MODELS_DIR:       ${MODELS_DIR}"

# -- 
YEAR=$(date +%Y)
RAW_DESTINATION="${RAW_DATA}/${YEAR}/${RUN_ID}/"
PROCESSED_DATA_DIR=${PROCESSED_DATA}/${YEAR}/${RUN_ID}
PROCESSED_BAM="${PROCESSED_DATA_DIR}/all_barcodes.bam"
DEMUX_DIR="${PROCESSED_DATA_DIR}/demux"
LOGS_DIR="$PROCESSED_DATA_DIR/logs"
LOG_OUT="${LOGS_DIR}/%j_%x.out"

mkdir -p $RAW_DESTINATION
mkdir -p $PROCESSED_DATA_DIR
mkdir -p $LOGS_DIR

JOB_VARIABLES="${PROCESSED_DATA_DIR}/pipeline_vars.env"

echo "RAW_DATA=${RAW_DATA}" > $JOB_VARIABLES
echo "PROCESSED_DATA=${PROCESSED_DATA}" >> $JOB_VARIABLES
echo "REFERENCE_LINKS=${REFERENCE_LINKS}" >> $JOB_VARIABLES
echo "RMSK_BED=${RMSK_BED}" >> $JOB_VARIABLES
echo "MODELS_DIR=${MODELS_DIR}" >> $JOB_VARIABLES
echo "RAW_DESTINATION=${RAW_DESTINATION}" >> $JOB_VARIABLES
echo "SOURCE=${SOURCE}" >> $JOB_VARIABLES
echo "RUN_ID=${RUN_ID}" >> $JOB_VARIABLES
echo "PROCESSED_DATA_DIR=${PROCESSED_DATA_DIR}" >> $JOB_VARIABLES
echo "PROCESSED_BAM=${PROCESSED_BAM}" >> $JOB_VARIABLES
echo "DEMUX_DIR=${DEMUX_DIR}" >> $JOB_VARIABLES
echo "JOB_VARIABLES=${JOB_VARIABLES}" >> $JOB_VARIABLES


# Step 1: Copy the data
# echo "Submitting data copy job"
# job_data_copy_id=$(sbatch --parsable \
#   --output="$LOG_OUT" \
#   1_copy_from_grid.sbatch ${SOURCE} ${RAW_DESTINATION} ${JOB_VARIABLES})

# cleanup_id=$(sbatch --parsable \
#   --export=ALL,JOB_VARIABLES=$JOB_VARIABLES \
#   --output="$LOG_OUT" \
#   --dependency=afternotok:$job_data_copy_id \
#   error.sbatch --step copy_failed)

# Step2: Basecall with dependency
# echo "Submitting basecalling job (depends on ${job_data_copy_id})"
# job_basecall_id=$(sbatch --parsable \
#   --output="$LOG_OUT" \
#   --dependency=afterok:$job_data_copy_id \
#   2_dorado_basecall.sbatch ${RAW_DESTINATION} ${PROCESSED_BAM} ${JOB_VARIABLES})

# Step2: Basecall
echo "Submitting basecalling job"
job_basecall_id=$(sbatch --parsable \
  --output="$LOG_OUT" \
  2_dorado_basecall.sbatch ${RAW_DESTINATION} ${PROCESSED_BAM} ${JOB_VARIABLES})

echo "Submitting demux job (depends on ${job_basecall_id})"
job_demux_id=$(sbatch --parsable \
  --output="$LOG_OUT" \
  --dependency=afterok:$job_basecall_id \
  3_dorado_demux.sbatch ${PROCESSED_BAM} ${DEMUX_DIR} ${JOB_VARIABLES})
