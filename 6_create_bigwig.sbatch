#!/usr/bin/env bash
#SBATCH --partition=cpu_short
#SBATCH --job-name=bigwig
#SBATCH --mem=32Gb
#SBATCH --time=0-12:00:00
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=32
#SBATCH --nodes=1

set -euo pipefail

source ${JOB_VARIABLES}

echo "Command: $0 $@"

module load bedtools/2.30.0
module load ucscutils/398
module load samtools/1.20

usage() {
  echo "Usage: $0 <sorted_bam_file> <fasta_reference> <adaptive_targets> <rmsk bed>"
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

if [[ $# -ne 4 ]]; then
  echo "Error: incorrect number of arguments provided"
  usage
fi




SORTED_BAM_FILE=$1

# == FROM ENV VARS FILE CREATED BY submit.sh ==
REFERENCE=${REFERENCE_FASTA}
INPUT_ANNOTATION=${TARGETS_BED}
RMSK_BED=${RMSK_BED}

BAM_FILENAME=$(basename "$SORTED_BAM_FILE")
REFERENCE_FILENAME=$(basename "${REFERENCE}")

REFERENCE_NAME="${REFERENCE_FILENAME%.*}"
CHROM_SIZES="${REFERENCE%.fa}".chrom.sizes
BIGWIG_FILE="${SORTED_BAM_FILE%.aligned.sorted.bam}".bw
BG_BIGWIG_FILE="${SORTED_BAM_FILE%.aligned.sorted.bam}".window.100kb.coverage.mean.bw
SAMPLE_ID="${BAM_FILENAME%%-*}"
TMP_OUT=$TMPDIR/$SAMPLE_ID
BEDGRAPH_FILE="${SORTED_BAM_FILE%.aligned.sorted.bam}".bed



mkdir -p $TMP_OUT

echo "REFERENCE_NAME: ${REFERENCE_NAME}"
echo "CHROM_SIZES:    ${CHROM_SIZES}"
echo "BEDGRAPH_FILE:  ${BEDGRAPH_FILE}"
echo "BIGWIG_FILE:    ${BIGWIG_FILE}"
echo "BG_BIGWIG_FILE: ${BG_BIGWIG_FILE}"
echo "SAMPLE_ID:      ${SAMPLE_ID}"
echo "TMP_OUT:        ${TMP_OUT}"

# Generate chromosome sizes file if needed
if [ ! -f "$CHROM_SIZES" ]; then
    echo "Generating chromosome sizes file..."
    samtools faidx "$REFERENCE"
    cut -f1,2 "${REFERENCE}.fai" > "$CHROM_SIZES"
fi


start_time=$(date +%s)
echo "Arguments: ${SORTED_BAM_FILE} ${BEDGRAPH_FILE} ${BIGWIG_FILE} ${CHROM_SIZES}"
echo "Job properties: ${SLURM_CPUS_PER_TASK} ${SLURM_NODELIST}"
# Step 4: BedGraph and BigWig
echo "Step 1: Generating bedGraph..."
bedtools genomecov -ibam "$SORTED_BAM_FILE" -bg > "$BEDGRAPH_FILE"

echo "Step 2: Converting bedGraph to bigWig..."
bedGraphToBigWig "$BEDGRAPH_FILE" "$CHROM_SIZES" "$BIGWIG_FILE"

echo "Step 3: Creating chromosome windows..."
WINDOW_FILE="${TMP_OUT}/${REFERENCE_NAME}.windows.100kb.sort.bed"
bedtools makewindows \
  -g $CHROM_SIZES \
  -w 100000 -s 100000 \
  | sort -k1,1 -k2,2n > $WINDOW_FILE

echo "Step 4: Removing Adaptive target regions & rmsk regions..."
INTERSECT_OUT="${TMP_OUT}/${SAMPLE_ID}.masked.sorted.bed"
bedtools intersect \
  -a  $BEDGRAPH_FILE\
  -b $RMSK_BED $INPUT_ANNOTATION \
  -v | sort -k1,1 -k2,2n > $INTERSECT_OUT

echo "Step 5: Split intersected bed into windows..."
SPLIT_WINDOWS="${TMP_OUT}/${SAMPLE_ID}.masked.100kb_binned.bed"
bedtools intersect \
  -a $WINDOW_FILE \
  -b $INTERSECT_OUT \
  -sorted \
  -wb -sortout > $SPLIT_WINDOWS

echo "Step 6: Calculating per base depth..."
PER_BASE_DEPTH_OUT="${TMP_OUT}/${SAMPLE_ID}.masked.per_base_depth.bed"
cat $SPLIT_WINDOWS | cut -f1-3,7 | awk '{print $1"\t"$2"\t"$3"\t"($3-$2)*$4}' > $PER_BASE_DEPTH_OUT

echo "Step 7: Calculate total per base depth per window..."
# MAP_OUT="ONT00005-mES_JB5_hTBXT_Scarless_clHLA296.bg.masked.per_base_depth.windowed.bed"
MAP_OUT="${TMP_OUT}/${SAMPLE_ID}.masked.per_base_depth.windowed.bed"
bedtools map \
  -b $PER_BASE_DEPTH_OUT \
  -a $WINDOW_FILE \
  -c 4 \
  -o sum \
  -null 0 > $MAP_OUT

echo "Step 8: Calculate mean coverage per window..."
WINDOW_MEAN="${TMP_OUT}/${SAMPLE_ID}.window.100kb.coverage.mean.bed"
cat $MAP_OUT | grep -v "0$" | awk '{ print $1"\t"$2"\t"$3"\t"$4/($3-$2) }' > $WINDOW_MEAN

echo "Step 9: Creating background bw file..."
bedGraphToBigWig \
  $WINDOW_MEAN \
  $CHROM_SIZES \
  $BG_BIGWIG_FILE

end_time=$(date +%s)
execution_time_minutes=$((end_time-start_time))
echo "Script execution time: $execution_time_minutes seconds"
