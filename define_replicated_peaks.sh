#define_replicated_peaks.sh
#!/bin/bash
# sh define_replicated_peaks.sh to see the help message
usage() {
  echo "Usage: $0 [-p pooled_peaks.bed] [-i individual_peaks1.bed,individual_peaks2.bed,...] [-m min_replicates] [-g chromosome_order_file]"
  echo "Options:"
  echo "  -h  Show this help message"
  echo "  -p  Path to the pooled peaks file (narrowPeak, broadPeak or bed format)"
  echo "  -i  Comma-separated list of individual peaks files"
  echo "  -m  Minimum number of donors for a peak to be considered replicated"
  echo "  -g  Path to file with order of chromosomes for sorting (optional)"
  exit 1
}
# Check if no arguments are provided
if [ $# -eq 0 ]; then
  usage
fi

# If -h is provided, show the help message
if [[ "$1" == "-h" ]]; then
  usage
fi

order="default" # Default sorting order
# Initialize variables
while getopts ":p:i:m:g:" opt; do
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
    g )
      if [ -r "$OPTARG" ]; then
        order="$OPTARG"
	echo "Using chromosome order file: $OPTARG"
      fi
      ;;
    * )
      echo "Invalid command. Please ensure the following arguments are provided:"
	    echo "[-p] narrowPeak, broadPeak or bed format pooled peaks file from macs2."
	    echo "[-i] Individual peak files in a comma separated list."
	    echo "[-m] Minimum number of donors for replicated peaks."
      ;;
  esac
done

# Define sort command based on chromosome order file
if [ "$order" = "default" ]; then
  echo "No valid chromosome order file provided, defaulting to sort -k1V,1 -k2,2n."
  sort_cmd="sort -k1V,1 -k2,2n"
else
  sort_cmd="bedtools sort -g $order -i -"
fi

# Sort the pooled peak file
cut -f 1-3 $pooled | $sort_cmd | uniq > pooled_peaks.bed

# Set the number of replicates using the array length
nreplicates=${#array[@]}

# Intersect the pooled peak file with the first individual donor ${array[0]}
cut -f 1-3 ${array[0]} | $sort_cmd | intersectBed -c -e -f 0.5 -F 0.5 -a pooled_peaks.bed -b - > pooled_intersections.bed

#Check if the first intersection file is empty
if [ ! -s pooled_intersections.bed ]; then
  echo "No peaks found in the pooled peak file. Exiting."
  exit 1
fi

#Loop over the rest of the individual donor files
for donor in $(seq 1 $((nreplicates -1))); do
	cut -f 1-3 ${array[$donor]} | $sort_cmd | intersectBed -c -e -f 0.5 -F 0.5 -a pooled_intersections.bed -b - > tmp
	# Rename the temporary file to pooled_intersections.bed
	mv tmp pooled_intersections.bed
done

#Create a new file with the number of donors the peak is replicated in, called replicated_peaks.txt (this is optional)
header="chr\tstart\tend"
for donor in ${array[@]}; do
	header="$header""\t$donor"
done

printf "$header\ttotal_replicates\n" > replicated_peaks.txt
startcolumn=4
maxcolumn=$(( 3 + $nreplicates))

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
sed '1d' replicated_peaks.txt | awk -v OFS='\t' -v FS='\t' -v rep=$(( 1 + $maxcolumn)) -v min=$min '{if($rep >= min) print $1,$2,$3}' > replicated_peaks.bed

replicatedn=$(wc -l replicated_peaks.bed | awk '{print $1}')
echo "$replicatedn peaks are replicated in at least $min donors." 

cat replicated_peaks.bed | $sort_cmd > tmp; mv tmp replicated_peaks.bed
echo "Replicated peaks saved to replicated_peaks.bed"

rm pooled_peaks.bed
rm pooled_intersections.bed

# Clean up temporary files
rm -f tmp
echo "Temporary files cleaned up."
# End of script