#!/usr/bin/env bash
#SBATCH --partition=cpu_short
#SBATCH --job-name=methylation
#SBATCH --mem=32Gb
#SBATCH --time=0-12:00:00
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=16
#SBATCH --nodes=1
#SBATCH --mail-type=FAIL      # Mail events (NONE, BEGIN, END, FAIL, ALL)
#SBATCH --mail-user=mark.grivainis@nyulangone.org     # Where to send mail

set -euo pipefail

echo "Command: $0 $@"
module load bedtools/2.30.0
module load ucscutils/398
module load samtools

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
RMSK_BED=${RMSK_BED}

BAM_FILENAME=$(basename "$SORTED_BAM_FILE")
REFERENCE_FILENAME=$(basename "${REFERENCE}")

REFERENCE_NAME="${REFERENCE_FILENAME%.*}"
REF_FAI="${REFERENCE_FASTA}.fai"
CHROM_SIZES="${REFERENCE%.fa}".chrom.sizes
MOD_BIGWIG_PREFIX="${SORTED_BAM_FILE%.aligned.sorted.bam}"
SAMPLE_ID="${BAM_FILENAME%%-*}"
BEDGRAPH_PREFIX="${SORTED_BAM_FILE%.aligned.sorted.bam}"

# Flags to determine what tracks to build
HAS_CPG_MODEL=false
HAS_ALL_C_MODEL=false
HAS_6MA=false

if [[ "$BC_MODEL" == *"5mCG_5hmCG"* ]]; then HAS_CPG_MODEL=true; fi
if [[ "$BC_MODEL" == *"5mC_5hmC"* ]]; then HAS_ALL_C_MODEL=true; fi
if [[ "$BC_MODEL" == *"6mA"* ]]; then HAS_6MA=true; fi

# Generate chromosome sizes file if needed
if [ ! -f "$CHROM_SIZES" ]; then
    echo "Generating chromosome sizes file..."
    samtools faidx "$REFERENCE"
    cut -f1,2 "${REFERENCE}.fai" > "$CHROM_SIZES"
fi

# --- Step 1: Cytosine Pileup (5mC/5hmC) ---
if [ "$HAS_CPG_MODEL" = true ] || [ "$HAS_ALL_C_MODEL" = true ]; then
    CYTO_BED="${BEDGRAPH_PREFIX}_cytosine_pileup.bed.gz"

    # Base command structure
    PILEUP_ARGS=(
      "${SORTED_BAM_FILE}"
      "${CYTO_BED}"
      "--modified-bases" "5mC" "5hmC"
      "--ref" "${REFERENCE_FASTA}"
      "--bgzf"
    )

    # Apply CpG specific optimization and strand combining if it's the CpG model
    if [ "$HAS_CPG_MODEL" = true ]; then
        echo "Running combined-strand pileup for CpG (5mC/5hmC)..."
        # --cpg is the built-in palindromic motif flag allowed with strand combining
        PILEUP_ARGS+=("--cpg" "--combine-strands")
        SUFFIX="cpg"
    else
        echo "Running all-context pileup for Cytosines (5mC/5hmC)..."
        SUFFIX="all_c"
    fi

    # Run Cytosine Pileup
    /gpfs/data/broshr01lab/tools/dist_modkit_v0.6.1_481e3c9/modkit pileup "${PILEUP_ARGS[@]}"

    # Generate Cytosine BigWig Track
    echo "-> Creating Cytosine (${SUFFIX}) Methylation bigWig..."
    echo "-> Bigwig output: ${MOD_BIGWIG_PREFIX}_${SUFFIX}_methylation.mod.bw"
    zcat "${CYTO_BED}" | /gpfs/data/broshr01lab/tools/dist_modkit_v0.6.1_481e3c9/modkit bedmethyl tobigwig \
      - \
      "${MOD_BIGWIG_PREFIX}_${SUFFIX}_methylation.bw" \
      --mod-codes m,h \
      -g "${REF_FAI}"
fi

# --- Step 2: Adenine Pileup (6mA) ---
if [ "$HAS_6MA" = true ]; then
    A_BED="${BEDGRAPH_PREFIX}_6mA_pileup.bed.gz"
    echo "Running pileup for Adenine (6mA)..."

    # 6mA cannot use --combine-strands because single 'A' isn't a palindrome.
    /gpfs/data/broshr01lab/tools/dist_modkit_v0.6.1_481e3c9/modkit pileup \
      "${SORTED_BAM_FILE}" \
      "${A_BED}" \
      --modified-bases 6mA \
      --ref "${REFERENCE_FASTA}" \
      --bgzf

    # Generate 6mA BigWig Track
    echo "-> Creating Adenine (6mA) bigWig..."
    zcat "${A_BED}" | /gpfs/data/broshr01lab/tools/dist_modkit_v0.6.1_481e3c9/modkit bedmethyl tobigwig \
      - \
      "${MOD_BIGWIG_PREFIX}_adenine_6mA.bw" \
      --mod-codes a \
      -g "${REF_FAI}"
fi

echo "Pipeline complete! Generated files successfully."
