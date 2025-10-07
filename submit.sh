#!/usr/bin/env bash

set -euo pipefail

# Check if the correct number of arguments were provided.
if [ "$#" -le 6 ]; then
    echo "Usage: $0 <source_directory> <run_id> <reference_dir_name> [-o <barcode> <sample_id> <sample_name> ...]"
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
REFERENCE_DIR="$3"

shift 3

BARCODES=()
SAMPLE_IDS=()
SAMPLE_NAMES=()


# Loop through the remaining arguments and store them in the array
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o)
      if [ "$#" -lt 4 ]; then
        echo "Error: -o requires a key and a value."
        exit 1
      fi
      BARCODES+=("$2")
      SAMPLE_IDS+=("$3")
      SAMPLE_NAMES+=("$4")
      shift 4
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

# -- 
YEAR=$(date +%Y)
RAW_DESTINATION="${RAW_DATA}/${YEAR}/${RUN_ID}/"
PROCESSED_DATA_DIR=${PROCESSED_DATA}/${YEAR}/${RUN_ID}
PROCESSED_BAM="${PROCESSED_DATA_DIR}/all_barcodes.bam"
DEMUX_DIR="${PROCESSED_DATA_DIR}/demux"

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

pipeline_job_ids=()

# Step 1: Copy the data


echo "Submitting data copy job"
echo "  SOURCE:      ${SOURCE}"
echo "  DESTINATION: ${RAW_DESTINATION}"

job_data_copy_id=$(sbatch --parsable manual_scripts/1_copy_from_grid.sbatch ${SOURCE} ${RAW_DESTINATION})
pipeline_job_ids+=($job_data_copy_id)

# Step2: Basecall

echo "Submitting basecalling job (depends on ${job_data_copy_id})"
echo "  RAW_DATA:       ${RAW_DESTINATION}"
echo "  PROCESSED_DATA: ${PROCESSED_BAM}"

job_basecall_id=$(sbatch --parsable --dependency=afterok:$job_data_copy_id manual_scripts/2_dorado_basecall.sbatch ${RAW_DESTINATION} ${PROCESSED_BAM})
pipeline_job_ids+=($job_basecall_id)

# Step3: Demux
echo "Submitting demux job (depends on ${job_basecall_id})"
echo "  PROCESSED_DATA: ${PROCESSED_BAM}"
echo "  DEMUX_DIR:      ${DEMUX_DIR}"

job_demux_id=$(sbatch --parsable --dependency=afterok:$job_basecall_id manual_scripts/3_dorado_demux.sbatch ${PROCESSED_BAM} ${DEMUX_DIR})
pipeline_job_ids+=($job_demux_id)

# ---Per Sample Scripts---
echo "Submitting Sample Scripts"
for ((i=0; i<${#BARCODES[@]}; i++)); do
  BARCODE="${BARCODES[i]}"
  SAMPLE_ID="${SAMPLE_IDS[i]}"
  SAMPLE_NAME="${SAMPLE_NAMES[i]}"

  # Step4: Merge Barcodes
  SAMPLE_BAM="$PROCESSED_DATA_DIR/${SAMPLE_ID}-${SAMPLE_NAME}.bam"
  echo "  Submitting barcode merge jobs (depends on ${job_demux_id})"
  echo "    SAMPLE_BAM: ${SAMPLE_BAM}"
  echo "    BARCODE:    ${BARCODE}"
  echo "    DEMUX_DIR:  ${DEMUX_DIR}"

  job_merge_barcodes_id=$(sbatch --parsable --dependency=afterok:$job_demux_id manual_scripts/4_samtools_merge_barcode.sbatch "${SAMPLE_BAM}" "${BARCODE}" "${DEMUX_DIR}")
  pipeline_job_ids+=($job_merge_barcodes_id)

  # Step5: Align
  echo "  Submitting alignment job (depends on ${job_merge_barcodes_id})"
  echo "    SAMPLE_BAM:      ${SAMPLE_BAM}"
  echo "    REFERENCE_FASTA: ${REFERENCE_FASTA}"


  job_align_id=$(sbatch --parsable --dependency=afterok:$job_merge_barcodes_id manual_scripts/5_dorado_align.sbatch ${SAMPLE_BAM} ${REFERENCE_FASTA})
  pipeline_job_ids+=($job_align_id)
  
  # Step6: Generate coverage maps
  echo "  Submitting alignment job (depends on ${job_align_id})"
  echo "    SAMPLE_BAM:      ${SAMPLE_BAM}"
  echo "    REFERENCE_FASTA: ${REFERENCE_FASTA}"
  echo "    TARGETS_BED:     ${TARGETS_BED}"
  echo "    RMSK_BED:        ${RMSK_BED}"

  job_coverage_id=$(sbatch --parsable --depends=afterok:$job_align_id manual_scripts/6_create_bigwig.sbatch \
    ${SAMPLE_BAM} \
    ${REFERENCE_FASTA} \
    ${TARGETS_BED} \
    ${RMSK_BED})
  pipeline_job_ids+=($job_coverage_id)
  

done

# // leave out of automation for now
# sh manual_scripts/7_cleanup.sbatch /data/2025_09_24_PAX6__MK6_MC1_A9_C11/ /gpfs/data/broshr01lab/raw_data/2025/20250924a/

# // add step to update sample_reference_mapping.json with new samples and reference
# sh 8_build_registry.sbatch ../processed_data ../annotation_temporary ./igv_registry igv_registry_builder/sample_reference_mapping.json
#
#
# # Join the array elements with a colon
dependency_list=$(IFS=:; echo "${pipeline_job_ids[*]}")
echo " -> Cleanup job will depend on IDs: $dependency_list"

# TODO: pass the dependency list to the job to find out which job failed
cleanup_id=$(sbatch --parsable --dependency=afternotok:$dependency_list error.sbatch SOURCE RUN_ID REFERENCE_DIR)
echo " -> Cleanup job submitted with ID: $cleanup_id"

