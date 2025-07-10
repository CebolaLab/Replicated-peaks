# Defining replicated peaks

This Github contains a short guide to defining replicated peaks from the output of macs2.

The input can be **any number of replicates**, and you define the **minimum number of individual samples** the replicated peaks should appear in. 

The output replicated peaks are defined as peaks present in the **pooled** analysis and which are independently called in **n or more** biological replicates (you decide the n).

The files required for this analysis include:

- Pooled peaks (`.broadPeak`, `.narrowPeak`, `.bed`)
- Peaks for individual samples (`.broadPeak`, `.narrowPeak`, `.bed`)

Please see the previous tutorials https://github.com/CebolaLab/ATAC-seq and https://github.com/CebolaLab/ChIPmentation for instructions on how to generate these files.

The first step is to download the file `define_replicated_peaks.sh` (contents at the bottom of the page).

You can then run the script as shown below. I suggest you copy all peak files to the working directory, or create symbolic links using `ln -s`. The individual replicate files should be provided as a comma seperated list (the example below shows three samples, but you can have more than three). The arguments:

- `-p` Pooled peak file
- `-i` Individual peak files in a comma separated list."
- `-m` argument should include the minimum number of replicates you want your replicated peaks to be found in.
- `-g` optional, add a file with the chromosome order e.g. `chrName.txt`. If provided, files will be sorted using bedtools sort. If not provided, sorting will use `sort -k 1V,1 -k 2,2n`.

```bash
bash define_replicated_peaks.sh -p pooled_peaks.broadPeak -i sample_1.broadPeak,sample_2.broadPeak,sample_3.broadPeak -m 2
```
The contents of the shell script are shown below:

```bash
#define_replicated_peaks.sh
#!/bin/bash
# sh define_replicated_peaks.sh to see the help message
usage() {
  echo "Usage: $0 [-p pooled_peaks.bed] [-i individual_peaks1.bed,individual_peaks2.bed,...] [-m min_replicates]"
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
	    echo "[-g] Chromosome order file for sorting (optional)."
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
cut -f 1-3 ${array[0]} | $sort_cmd | uniq | intersectBed -c -e -f 0.5 -F 0.5 -a pooled_peaks.bed -b - > pooled_intersections.bed

#Check if the first intersection file is empty
if [ ! -s pooled_intersections.bed ]; then
  echo "No peaks found in the pooled peak file. Exiting."
  exit 1
fi

#Loop over the rest of the individual donor files
for donor in $(seq 1 $((nreplicates -1))); do
	cut -f 1-3 ${array[$donor]} | $sort_cmd | uniq | intersectBed -c -e -f 0.5 -F 0.5 -a pooled_intersections.bed -b - > tmp
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

sed '1d' replicated_peaks.txt | awk -v OFS='\t' -v FS='\t' -v rep=$(( 1 + $maxcolumn)) -v min=$min '{if($rep >= min) print $1,$2,$3}' > replicated_peaks.bed

replicatedn=$(wc -l replicated_peaks.bed | awk '{print $1}')
echo "$replicatedn peaks are replicated in at least $min donors." 

cat replicated_peaks.bed | $sort_cmd | uniq > tmp; mv tmp replicated_peaks.bed
echo "Replicated peaks saved to replicated_peaks.bed"

rm pooled_peaks.bed
rm pooled_intersections.bed
```
