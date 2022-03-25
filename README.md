# Defining replicated peaks (macs2)

This Github contains a short guide to defining replicated peaks from the output of macs2.

Replicated peaks are defined as peaks present in the **pooled** analysis and which are independently called in **two or more** biological replicates. 


The files required for this analysis include:

- macs2 pooled peaks
- macs2 peaks for individual samples

Please see the previous tutorials https://github.com/CebolaLab/ATAC-seq and https://github.com/CebolaLab/ChIPmentation for instructions on how to generate these files.


The first step runs this shell script:

```bash
sh define_replicated_peaks.sh n min pooled_peaks.bed donor1_peaks.bed,donor2_peaks.bed...
```

Where n, the total number of individual replicates, is followed by the minimum number of replicates you require to define a "replicated" peak (e.g. a minimum of two replicates). Then, the name of the pooled peaks file should be followed by a comma seperated list with the individual replicate files.

The contents of the shell script are shown below:

```bash
#define_replicated_peaks.sh

declare -i n=$1
declare -i min=$2
pooled=$3
list=$4

IFS=',' read -r -a array <<< "$list"

#Bedtools allows only up to 12 columns, so we need to remove the extra columns for this analysis. We will keep just the 
#coordinates and names of the peaks, which we can use later to extract back the replicated peaks from the original file.
cut -f 1-4 $pooled > pooled_tmp.bed

#Run the intersection with the pooled file and first individual dataset to create the tmp file
intersectBed -c -a pooled_tmp.bed -b ${array[0]} > tmp

#The rest should be run for the array range 1 to the max (minus 1, since bash arrays start from 0)
Nminus1=$(expr $n - 1)
for x in $(seq 1 $Nminus1)
do 
     intersectBed -c -a tmp -b ${array[$x]} > tmp2; mv tmp2 tmp #each loop will overwrite the tmp file
done

#We want the number of overlaps (i.e. non 0 values) to be at least your minimum requirement.
#$n is the number of datasets, $min is your minimum number of datasets to define a "replicated peak".
#The maximum number of '0' can be n - min. 
declare -i maxmissing="$(($n-$min))"

awk -v maxmissing=$maxmissing '{peak=$4; $1=$2=$3=$4=" "; gsub(/[0]/, ""); if(missing < $maxmissing) print peak}' tmp | grep -wf - $pooled > replicated_peaks.bed

rm pooled_tmp.bed
rm tmp
```

The output file is called `replicated_peaks.bed`.
