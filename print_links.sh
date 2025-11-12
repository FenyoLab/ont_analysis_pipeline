RUN_DIR=$1

echo "---BAM Links---"
find $RUN_DIR -type f -name "*.aligned.sorted.bam" | sort | sed 's/^.*processed_data/https:\/\/ont:longreads@cascade.isg.med.nyu.edu\/broshr01lab\/data/g'

echo "---BAI Links---"
find $RUN_DIR -type f -name "*.aligned.sorted.bam.bai" | sort | sed 's/^.*processed_data/https:\/\/ont:longreads@cascade.isg.med.nyu.edu\/broshr01lab\/data/g'

echo "---Coverage Links---"
find $RUN_DIR -type f -name "*.bw" -not -name "*.mean.bw" | sort | sed 's/^.*processed_data/https:\/\/ont:longreads@cascade.isg.med.nyu.edu\/broshr01lab\/data/g'

echo "---Smoothed Coverage Links---"
find $RUN_DIR -type f -name "*.mean.bw" | sort | sed 's/^.*processed_data/https:\/\/ont:longreads@cascade.isg.med.nyu.edu\/broshr01lab\/data/g'

echo "---Sniffles Links---"
find $RUN_DIR -type f -name "*.vcf.gz" | sort | sed 's/^.*processed_data/https:\/\/ont:longreads@cascade.isg.med.nyu.edu\/broshr01lab\/data/g'

echo "---Sniffles tbi Links---"
find $RUN_DIR -type f -name "*.tbi" | sort | sed 's/^.*processed_data/https:\/\/ont:longreads@cascade.isg.med.nyu.edu\/broshr01lab\/data/g'
