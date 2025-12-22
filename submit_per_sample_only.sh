#!/usr/bin/env bash

set -euo pipefail

# Check if the correct number of arguments were provided.
if [ "$#" -le 6 ]; then
    echo "Usage: $0 <source_directory> <run_id> <species mm10|hg38> [-o <barcode> <sample_id> <sample_name> <reference_fasta_path> ...]"
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
SPECIES="$3"

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

RMSK_BED=${ANNOTATIONS_DIR}/{$SPECIES}/rmsk.sorted.bed
echo "RMSK_BED:         ${RMSK_BED}"

RAW_DESTINATION="${RAW_DATA}/${YEAR}/${RUN_ID}/"
PROCESSED_DATA_DIR=${PROCESSED_DATA}/${YEAR}/${RUN_ID}
PROCESSED_BAM="${PROCESSED_DATA_DIR}/all_barcodes.bam"
DEMUX_DIR="${PROCESSED_DATA_DIR}/demux"
LOGS_DIR="$PROCESSED_DATA_DIR/logs"
LOG_OUT="${LOGS_DIR}/%j_%x.out"

JOB_VARIABLES="${PROCESSED_DATA_DIR}/pipeline_vars.env"

source $JOB_VARIABLES

# ---Per Sample Scripts---
echo "Submitting Sample Scripts"
for ((i=0; i<${#BARCODES[@]}; i++)); do
  BARCODE="${BARCODES[i]}"
  SAMPLE_ID="${SAMPLE_IDS[i]}"
  SAMPLE_NAME="${SAMPLE_NAMES[i]}"
  REFERENCE_FASTA="${REFERENCE_FASTAS[i]}"

  # # Step4: Merge Barcodes
  SAMPLE_BAM="$PROCESSED_DATA_DIR/${SAMPLE_ID}-${SAMPLE_NAME}.bam"
  SORTED_BAM_OUTPUT="${SAMPLE_BAM%.*}".aligned.sorted.bam
  # echo "  Submitting barcode merge jobs"
  # job_merge_barcodes_id=$(sbatch --parsable \
  #   --output="$LOG_OUT" \
  #   --nodelist=cn-0005,cn-0021,cn-0034 \
  #   4_samtools_merge_barcode.sbatch "${SAMPLE_BAM}" "${BARCODE}" "${DEMUX_DIR}" ${JOB_VARIABLES})

  # # Step5: Align
  # echo "  Submitting alignment job (depends on ${job_merge_barcodes_id})"
  # job_align_id=$(sbatch --parsable \
  #   --output="$LOG_OUT" \
  #   --nodelist=cn-0005,cn-0021,cn-0034 \
  #   --dependency=afterok:$job_merge_barcodes_id \
  #   5_dorado_align.sbatch ${SAMPLE_BAM} ${REFERENCE_FASTA} ${JOB_VARIABLES})

  # Step5: Align
  echo "  Submitting alignment job"
  job_align_id=$(sbatch --parsable \
    --output="$LOG_OUT" \
    --nodelist=cn-0005,cn-0021,cn-0034 \
    5_dorado_align.sbatch \
    ${SAMPLE_BAM} ${REFERENCE_FASTA} ${JOB_VARIABLES})
  
  # Step6: Generate coverage maps
  echo "  Submitting bigwig job (depends on ${job_align_id})"
  job_coverage_id=$(sbatch --parsable \
    --output="$LOG_OUT" \
    --nodelist=cn-0005,cn-0021,cn-0034 \
    --dependency=afterok:$job_align_id \
    6_create_bigwig.sbatch \
    ${SORTED_BAM_OUTPUT} ${REFERENCE_FASTA} ${JOB_VARIABLES})

  # # Step6: Generate coverage maps
  # echo "  Submitting bigwig job"
  # job_coverage_id=$(sbatch --parsable \
  #   --output="$LOG_OUT" \
  #   --nodelist=cn-0005,cn-0021,cn-0034 \
  #   6_create_bigwig.sbatch \
  #   ${SORTED_BAM_OUTPUT} ${REFERENCE_FASTA} ${JOB_VARIABLES})

  echo "  Submitting SV calling job (depends on ${job_coverage_id})"
  job_coverage_id=$(sbatch --parsable \
    --output="$LOG_OUT" \
    --nodelist=cn-0005,cn-0021,cn-0034 \
    --dependency=afterok:$job_coverage_id \
    9_structural_variant_calling.sbatch \
    ${SORTED_BAM_OUTPUT} ${REFERENCE_FASTA} ${JOB_VARIABLES})
done

# // leave out of automation for now
# sh 7_cleanup.sbatch /data/2025_09_24_PAX6__MK6_MC1_A9_C11/ /gpfs/data/broshr01lab/raw_data/2025/20250924a/

# // add step to update sample_reference_mapping.json with new samples and reference
# sh 8_build_registry.sbatch ../processed_data ../annotation_temporary ./igv_registry igv_registry_builder/sample_reference_mapping.json
