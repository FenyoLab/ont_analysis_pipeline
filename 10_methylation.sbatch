#!/usr/bin/env bash
#SBATCH --partition=cpu_short
#SBATCH --job-name=methylation
#SBATCH --mem=32Gb
#SBATCH --time=0-12:00:00
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=16
#SBATCH --nodes=1

set -euo pipefail

echo "Command: $0 $@"

module load bedtools/2.30.0
module load ucscutils/398
module load samtools/1.20

usage() {
  echo "Usage: $0 <sorted_bam_file> <fasta_reference>"
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

if [[ $# -ne 3 ]]; then
  echo "Error: incorrect number of arguments provided"
  usage
fi




SORTED_BAM_FILE=$1
REFERENCE_FASTA=$2
JOB_VARIABLES="$3"

source ${JOB_VARIABLES}


# == FROM ENV VARS FILE CREATED BY submit.sh ==
REFERENCE=${REFERENCE_FASTA}
INPUT_ANNOTATION=${TARGETS_BED}
RMSK_BED=${RMSK_BED}

BAM_FILENAME=$(basename "$SORTED_BAM_FILE")
REFERENCE_FILENAME=$(basename "${REFERENCE}")

REFERENCE_NAME="${REFERENCE_FILENAME%.*}"
CHROM_SIZES="${REFERENCE%.fa}".chrom.sizes
MOD_BIGWIG_FILE="${SORTED_BAM_FILE%.aligned.sorted.bam}".mod.bw
SAMPLE_ID="${BAM_FILENAME%%-*}"
TMP_OUT=$TMPDIR/$SAMPLE_ID
BEDGRAPH_FILE="${TMP_OUT}/mod.bedmethyl"


mkdir -p $TMP_OUT

# Generate chromosome sizes file if needed
if [ ! -f "$CHROM_SIZES" ]; then
    echo "Generating chromosome sizes file..."
    samtools faidx "$REFERENCE"
    cut -f1,2 "${REFERENCE}.fai" > "$CHROM_SIZES"
fi

echo "Step 1: Pileup"
/gpfs/data/broshr01lab/tools/dist_modkit_v0.6.1_481e3c9/modkit pileup $SORTED_BAM_FILE $BEDGRAPH_FILE --cpg --modified-bases 5mC 5hmC --reference $REFERENCE_FASTA --threads 16 --suppress-progress
echo "Step 1 complete"

echo "Step 2: Convert to BW"
/gpfs/data/broshr01lab/tools/dist_modkit_v0.6.1_481e3c9/modkit bedmethyl tobigwig $BEDGRAPH_FILE $MOD_BIGWIG_FILE --mod-code h,m -g $CHROM_SIZES --negative-strand-values -t 16 --suppress-progress
echo "Step 2 complete"
