#!/bin/bash

while getopts ":p:i:m:" opt; do
	case $opt in
    p )
      pooled="$OPTARG"
      line_count=$(wc -l < "$OPTARG" | awk '{ print $1 }')
      echo "Pooled file is $OPTARG with $line_count peaks." #$pooled"
      ;;
    i )
      individual="$OPTARG"
      IFS=', ' read -ra array <<< "$individual"
      for file in "${array[@]}"; do
        line_count=$(wc -l < "$file" | awk '{ print $1 }')
        echo "Individual file $file has $line_count peaks."
      done
      ;;
    m )
      min="$OPTARG"
      echo "Minimum number of replicates: $min"
      ;;
    * )
      echo "Invalid command. Please ensure the following arguments are provided:"
	    echo "[-p] narrowPeak or broadPeak pooled peaks file from macs2."
	    echo "[-i] Individual peak files in a comma separated list."
	    echo "[-m] Minimum number of donors for replicated peaks."
      ;;
  esac
done

#Sort the pooled peak file
cut -f 1-4 $pooled | sort -k1V,1 -k2,2n > pooled_peaks.bed

#Set the number of replicates using the array length
nreplicates=${#array[@]}

#Intersect the pooled peak file with the first individual donor ${array[0]}
cut -f 1-3 ${array[0]} | sort -k1V,1 -k2,2n | intersectBed -c -a pooled_peaks.bed -b - > pooled_intersections.bed

#Loop over the rest of the individual donor files
for donor in $(seq 1 $((nreplicates -1))); do
	cut -f 1-3 ${array[$donor]} | sort -k1V,1 -k2,2n | intersectBed -c -a pooled_intersections.bed -b - > tmp
	mv tmp pooled_intersections.bed
done

#Create a new file with the number of donors the peak is replicated in, called replicated_peaks.txt (this is optional)
header="chr\tstart\tend\tpeakname"
for donor in ${array[@]}; do
	header="$header""\t$donor"
done

printf "$header\ttotal_replicates\n" > replicated_peaks.txt
startcolumn=5
maxcolumn=$(( 4 + $nreplicates))

#Loop over the rows and sum the intersections 
awk -v OFS='\t' -v FS='\t' -v start="$startcolumn" -v max="$maxcolumn" '{
		sum=0
		for (i = start; i <= max; i++) {
			if ($i > 0) 
				sum++
		}
		print $0,sum
}' pooled_intersections.bed >> replicated_peaks.txt

echo $min
sed '1d' replicated_peaks.txt | awk -v OFS='\t' -v FS='\t' -v rep=$(( 1 + $maxcolumn)) -v min=$min '{if($rep >= min) print $1,$2,$3,$4}' > replicated_peaks.bed

replicatedn=$(wc -l replicated_peaks.bed | awk '{print $1}')
echo "$replicatedn peaks are replicated in at least $min donors." 

rm pooled_peaks.bed
rm pooled_intersections.bed
