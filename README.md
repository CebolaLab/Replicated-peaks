# Defining replicated peaks (macs2)

This Github contains a short guide to defining replicated peaks from the output of macs2.

The input can be **any number of replicates**, and you define the **minimum number of individual samples** the replicated peaks should appear in. 

The output replicated peaks are defined as peaks present in the **pooled** analysis and which are independently called in **n or more** biological replicates (you decide the n).

The files required for this analysis include:

- macs2 pooled peaks
- macs2 peaks for individual samples

Please see the previous tutorials https://github.com/CebolaLab/ATAC-seq and https://github.com/CebolaLab/ChIPmentation for instructions on how to generate these files.

The first step is to download the file `define_replicated_peaks.sh` (contents at the bottom of the page).

You can then run the script as shown below. I suggest you copy all broadPeak files to the working directory. The individual replicate files should be provided as a comma seperated list (the example below shows three samples, but you can have more than three). The arguments:

- `-p` Pooled peak file
- `-i` Individual peak files in a comma separated list."
- `-m` argument should include the minimum number of replicates you want your replicated peaks to be found in.

```bash
bash define_replicated_peaks.sh -p pooled_peaks.broadPeak -i sample_1.broadPeak,sample_2.broadPeak,sample_3.broadPeak -m 2
```
The contents of the shell script are shown below:

```bash
#define_replicated_peaks.sh
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
```