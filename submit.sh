#!/usr/bin/env bash

set -euo pipefail

# Check if the correct number of arguments were provided.
if [ "$#" -le 6 ]; then
    echo "Usage: $0 <source_directory> <run_id> <species mm10|hg38> [-o <barcode> <sample_id> <sample_name> <reference_fasta_path> ...]"
    echo "Example: $0 /path/on/remote/ 20250910 mm10 -o B6 ONT00001 Sample6 /ref"
    exit 1
fi

if [[ "$1" != /data/* ]]; then
    echo "ERROR: Source directory must start with '/data/' for safety."
    exit 1
fi

# -- Arguments
SOURCE="$1"
RUN_ID="$2"
SPECIES="$3"

shift 3

# Shift the -r argument
# TODO: [MG] in the future allow for multiple references. This will require moving
# each sample into it's own directory with its own variables
shift 1

REFERENCE_DIR=$1
LINK_NAME=$2
BED_FILE=$3

shift 3

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
      REFERENCE_FASTAS+=("$5")
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
echo "ANNOTATIONS_DIR:  ${ANNOTATIONS_DIR}"
echo "MODELS_DIR:       ${MODELS_DIR}"

# -- 
YEAR=$(date +%Y)

RMSK_BED=${ANNOTATIONS_DIR}/${SPECIES}/rmsk.sorted.bed
echo "RMSK_BED:         ${RMSK_BED}"

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
echo "TARGETS_BED=${REFERENCE_LINKS}/${LINK_NAME}/${BED_FILE}" >> $JOB_VARIABLES


if [ ! -L "${REFERENCE_LINKS}/${LINK_NAME}" ]; then
    ln -s ${RAW_DESTINATION}${REFERENCE_DIR} ${REFERENCE_LINKS}/${LINK_NAME}
    echo "Created soft link: ${REFERENCE_LINKS}/${LINK_NAME} -> ${RAW_DESTINATION}${REFERENCE_DIR}"
else
    echo "Soft link already exists: $LINK_NAME"
fi

# Step 1: Copy the data
echo "Submitting data copy job"
job_data_copy_id=$(sbatch --parsable \
  --output="$LOG_OUT" \
  1_copy_from_grid.sbatch ${SOURCE} ${RAW_DESTINATION} ${JOB_VARIABLES})

# cleanup_id=$(sbatch --parsable \
#   --export=ALL,JOB_VARIABLES=$JOB_VARIABLES \
#   --output="$LOG_OUT" \
#   --dependency=afternotok:$job_data_copy_id \
#   error.sbatch --step copy_failed)

# Step2: Basecall with dependency
echo "Submitting basecalling job (depends on ${job_data_copy_id})"
job_basecall_id=$(sbatch --parsable \
  --output="$LOG_OUT" \
  --dependency=afterok:$job_data_copy_id \
  2_dorado_basecall.sbatch ${RAW_DESTINATION} ${PROCESSED_BAM} ${JOB_VARIABLES})

# Step3: Demux
echo "Submitting demux job (depends on ${job_basecall_id})"
job_demux_id=$(sbatch --parsable \
  --output="$LOG_OUT" \
  --dependency=afterok:$job_basecall_id \
  --nodelist=cn-0005,cn-0021,cn-0034 \
  3_dorado_demux.sbatch ${PROCESSED_BAM} ${DEMUX_DIR} ${JOB_VARIABLES})

# ---Per Sample Scripts---
echo "Submitting Sample Scripts"
for ((i=0; i<${#BARCODES[@]}; i++)); do
  BARCODE="${BARCODES[i]}"
  SAMPLE_ID="${SAMPLE_IDS[i]}"
  SAMPLE_NAME="${SAMPLE_NAMES[i]}"
  REFERENCE_FASTA="${REFERENCE_LINKS}/${REFERENCE_FASTAS[i]}"

  # Step4: Merge Barcodes
  SAMPLE_BAM="$PROCESSED_DATA_DIR/${SAMPLE_ID}-${SAMPLE_NAME}.bam"
  SORTED_BAM_OUTPUT="${SAMPLE_BAM%.*}".aligned.sorted.bam
  echo "  Submitting barcode merge jobs (depends on ${job_demux_id})"
  job_merge_barcodes_id=$(sbatch --parsable \
    --output="$LOG_OUT" \
    --dependency=afterok:$job_demux_id \
    --nodelist=cn-0005,cn-0021,cn-0034 \
    4_samtools_merge_barcode.sbatch "${SAMPLE_BAM}" "${BARCODE}" "${DEMUX_DIR}" ${JOB_VARIABLES})

  # Step5: Align
  echo "  Submitting alignment job (depends on ${job_merge_barcodes_id})"
  job_align_id=$(sbatch --parsable \
    --output="$LOG_OUT" \
    --dependency=afterok:$job_merge_barcodes_id \
    --nodelist=cn-0005,cn-0021,cn-0034 \
    5_dorado_align.sbatch \
    ${SAMPLE_BAM} ${REFERENCE_FASTA} ${JOB_VARIABLES})

  # Step6: Generate coverage maps
  echo "  Submitting bed job (depends on ${job_align_id})"
  job_coverage_id=$(sbatch --parsable \
    --output="$LOG_OUT" \
    --dependency=afterok:$job_align_id \
    --nodelist=cn-0005,cn-0021,cn-0034 \
    6_create_bigwig.sbatch \
    ${SORTED_BAM_OUTPUT} ${REFERENCE_FASTA} ${JOB_VARIABLES})

  echo "  Submitting SV calling job (depends on ${job_coverage_id})"
  job_coverage_id=$(sbatch --parsable \
    --output="$LOG_OUT" \
    --dependency=afterok:$job_coverage_id \
    --nodelist=cn-0005,cn-0021,cn-0034 \
    9_structural_variant_calling.sbatch \
    ${SORTED_BAM_OUTPUT} ${REFERENCE_FASTA} ${JOB_VARIABLES})
done
