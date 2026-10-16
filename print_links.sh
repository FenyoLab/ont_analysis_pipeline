RUN_DIR=$1



echo "---BAM Links---"
find $RUN_DIR -type f -name "*.aligned.sorted.bam" | sort | sed 's/^.*processed_data/https:\/\/ont:longreads@cascade.isg.med.nyu.edu\/broshr01lab\/data/g'

echo "---BAI Links---"
find $RUN_DIR -type f -name "*.aligned.sorted.bam.bai" | sort | sed 's/^.*processed_data/https:\/\/ont:longreads@cascade.isg.med.nyu.edu\/broshr01lab\/data/g'

echo "---Coverage Links---"
find $RUN_DIR -type f -not -name "*.mod.bw" -not -name "*all_c_methylation.bw" -not -name "*cpg_methylation.bw" -not -name "*adenine_6mA.bw" -name "*.bw" -not -name "*.mean.bw" | sort | sed 's/^.*processed_data/https:\/\/ont:longreads@cascade.isg.med.nyu.edu\/broshr01lab\/data/g'

echo "---Smoothed Coverage Links---"
find $RUN_DIR -type f -name "*.mean.bw" | sort | sed 's/^.*processed_data/https:\/\/ont:longreads@cascade.isg.med.nyu.edu\/broshr01lab\/data/g'

echo "---Sniffles Links---"
find $RUN_DIR -type f -name "*.vcf.gz" | sort | sed 's/^.*processed_data/https:\/\/ont:longreads@cascade.isg.med.nyu.edu\/broshr01lab\/data/g'

echo "---Sniffles tbi Links---"
find $RUN_DIR -type f -name "*.tbi" | sort | sed 's/^.*processed_data/https:\/\/ont:longreads@cascade.isg.med.nyu.edu\/broshr01lab\/data/g'

readarray -d '' -t files < <(find $RUN_DIR -type f -iname "*.aligned.sorted.bam" -print0 | sort -z)

smooth=()
lttb=()
barplot=()

echo "Total files: ${#files[@]}"
# Iterate safely
for file in "${files[@]}"; do
  BASEFILE=$(basename  $file)
  SAMPLE_ID="${BASEFILE%%-*}"

  smooth_fig=$(find /gpfs/data/broshr01lab/figures -type f -name "${SAMPLE_ID}*smooth_25kb.svg" | sort | sed 's/^.*figures/https:\/\/ont:longreads@cascade.isg.med.nyu.edu\/broshr01lab\/figures/g')
  smooth+=($smooth_fig)


  lttb_fig=$(find /gpfs/data/broshr01lab/figures -type f -name "${SAMPLE_ID}*lttb_25kb.svg" | sort | sed 's/^.*figures/https:\/\/ont:longreads@cascade.isg.med.nyu.edu\/broshr01lab\/figures/g')
  lttb+=($lttb_fig)


  barplot_fig=$(find /gpfs/data/broshr01lab/figures -type f -name "${SAMPLE_ID}*barplot.svg" | sort | sed 's/^.*figures/https:\/\/ont:longreads@cascade.isg.med.nyu.edu\/broshr01lab\/figures/g')
  barplot+=($barplot_fig)
done

echo "---Figures:  smooth---"
for item in "${smooth[@]}"; do
  echo "$item"
done

echo "---Figures: lttb---"
for item in "${lttb[@]}"; do
  echo "$item"
done

echo "---Figures: barplot---"
for item in "${barplot[@]}"; do
  echo "$item"
done
