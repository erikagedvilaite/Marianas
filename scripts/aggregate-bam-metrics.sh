#! /bin/bash

# process *.read-counts files to get on-target vs off-target
cat *.read-counts > read-counts.txt
printf "Bam\tID\tTotalReads\tUnmappedReads\tTotalMapped\tUniqueMapped\tDuplicateFraction\tTotalOnTarget\tUniqueOnTarget\tTotalOnTargetFraction\tUniqueOnTargetFraction\n" > t
# add ID
awk 'BEGIN{FS=OFS="\t"}{ split($1, a, "_bc"); $1=$1"\t"a[1]; print }' read-counts.txt >> t
mv t read-counts.txt


# process coverage
printf "Sample\tTotalCoverage\tUniqueCoverage\n" > waltz-coverage.txt

# collect mean coverage from LocusPocus Metrics output
for f in `ls *-intervals.txt`
do
  sample="${f/-intervals.txt/}"
  sample=`echo $sample | awk 'BEGIN{FS="_bc"}{print $1}'`
  printf "$sample\t" >> waltz-coverage.txt

  totalCovarege=`awk 'BEGIN{FS=OFS="\t"}{L=L+$5; coverage=coverage+$5*$7;}END{print coverage/L}' $f`
  uniqueCovarege=`awk 'BEGIN{FS=OFS="\t"}{L=L+$5; coverage=coverage+$5*$7;}END{print coverage/L}' ${f/-intervals/-intervals-without-duplicates}`

  printf "$totalCovarege\t$uniqueCovarege\n" >> waltz-coverage.txt

done

# calculate per interval sum of coverage across all samples, both with and without duplicates
cat *-intervals.txt | awk 'BEGIN{FS=OFS="\t"; OFMT = "%.0f"}{ key=$1"\t"$2"\t"$3"\t"$4"\t"$5; value=coverage[key]; if(value==null){coverage[key]=$7; gc[key]=$8}else{coverage[key]=value+$7}}END{for(i in coverage){print i, gc[i], coverage[i]}}' | sort -k 4,4 > t1

cat *-intervals-without-duplicates.txt | awk 'BEGIN{FS=OFS="\t"; OFMT = "%.0f"}{ key=$4; value=coverage[key]; if(value==null){coverage[key]=$7;}else{coverage[key]=value+$7}}END{for(i in coverage){print i, coverage[i]}}' | sort -k 1,1 > t2

# put them in the same file
printf "Chr\tStart\tEnd\tIntervalName\tLength\tGC\tCoverage\tCoverageWithoutDuplicates\n" > intervals-coverage-sum.txt
awk 'BEGIN{FS=OFS="\t"; OFMT = "%.0f"}{getline line < "t1"; print line, $2}' t2 >> intervals-coverage-sum.txt
rm t1 t2

# collect per sample per interval coverage from LocusPocus Metrics output
printf "Interval\tSample\tTotalCoverage\tGC\n" > t5
printf "Interval\tSample\tUniqueCoverage\tGC\n" > t6

for f in `ls *-intervals.txt`
do
  sample="${f/-intervals.txt/}"
  sample=`echo $sample | awk 'BEGIN{FS="_bc"}{print $1}'`
  awk -v sample=$sample 'BEGIN{FS=OFS="\t"; OFMT = "%.0f"}{ print $4, sample, $7, $8}' $f >> t5
  awk -v sample=$sample 'BEGIN{FS=OFS="\t"; OFMT = "%.0f"}{ print $4, sample, $7, $8}'  ${f/-intervals/-intervals-without-duplicates} >> t6
done


######### Normalize coverage within sample and across samples and create R-friendly files

printf "Interval\tGene\tSample\tTotalCoverage\n" > t7
printf "Interval\tGene\tSample\tUniqueCoverage\n" > t8

for f in `ls *-intervals.txt`
do
  sample="${f/-intervals.txt/}"
  sample=`echo $sample | awk 'BEGIN{FS="_bc"}{print $1}'`

  # do only intra-sample normalization
  # sample mean as the normalizing factor
  normFactor=`awk 'BEGIN{FS=OFS="\t"}{intervals++; coverage+=$7;}END{print coverage/intervals}' $f`
  # sample median as the normalizing factor
  #normFactor=`awk 'BEGIN{FS=OFS="\t"}{values[NR]=$7}END{asort(values); if(NR%2==1){print values[(NR+1)/2]} else {print (values[NR/2] + values[(NR/2)+1])/2.0}}' $f`
  awk -v sample=$sample -v normFactor=$normFactor 'BEGIN{FS=OFS="\t"}{split($4, a, "_"); print $4, a[1], sample, $7/normFactor;}' $f >> t7

  # use both inter-sample and intra sample normalization
  #awk -v sample=$sample 'BEGIN{FS=OFS="\t"; while(getline < "locuspocus-coverage.txt"){if($1==sample) sampleCoefficient=1/$2}}{split($4, a, "_"); print $4, a[1], sample, $7*sampleCoefficient;}' $f > t
  #awk 'BEGIN{FS=OFS="\t"; while(getline < "t"){total+=$4}}{split($4, a, "_"); print $1, $2, $3, $4/total}' t >> t7

  # sample mean as the normalizing factor
  normFactor=`awk 'BEGIN{FS=OFS="\t"}{intervals++; coverage+=$7;}END{print coverage/intervals}' ${f/-intervals/-intervals-without-duplicates}`
  awk -v sample=$sample -v normFactor=$normFactor 'BEGIN{FS=OFS="\t";}{split($4, a, "_"); print $4, a[1], sample, $7/normFactor}'  ${f/-intervals/-intervals-without-duplicates} >> t8
done



# create the plots
echo  "plotting ..."
# ~/software/bin/plot-bam-metrics.R totalIntervalsLength??
echo -e "Done."










#
