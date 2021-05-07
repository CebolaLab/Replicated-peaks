# Defining replicated peaks (macs2)

This Github contains a short guide to defining replicated peaks from the output of macs2.

Replicated peaks are defined as peaks present in the **pooled** analysis and which are independently called in **two or more** biological replicates. 


The files required for this analysis include:

- macs2 pooled peaks
- macs2 peaks for individual samples

Please see the previous tutorials https://github.com/CebolaLab/ATAC-seq and https://github.com/CebolaLab/ChIPmentation for instructions on how to generate these files.


The first step runs this shell script:

```bash
sh define_replicated_peaks.sh n pooled_peaks.bed donor1_peaks.bed,donor2_peaks.bed... ncol
```

Where n, the total number of individual replicates, is followed by the name of the pooled peaks file, which is followed by a comma seperated list with the individual replicate files, then the number of columns in the input bed files (this should be the same for all bed files).

The contents of the shell script are shown below:

```bash
#define_replicated_peaks.sh

declare -i n
declare -i max
n=$1
pooled=$2

list=$3
IFS=',' read -r -a array <<< "$list"

min=1
max=$4
extra=$(($max + 2))
columns=$(echo $(seq -s, 1 $max),$extra)

intersectBed -wao -a $pooled -b ${array[0]} | cut -f $columns > peaks-overlap.bed

max=$(($max + 1))
extra=$(($extra + 1))

columns=$(echo $(seq -s, 1 $max),$extra)

for x in $(seq 2 $n)
do
     intersectBed -wao -a peaks-overlap.bed -b "${array[$x-1]}" | cut -f $columns > tmp
     mv tmp peaks-overlap.bed
     max=$(($max + 1))
     extra=$(($extra + 1))
     columns=$(echo $(seq -s, 1 $max),$extra)
done
```

The output file is called `peaks-overlap.bed`.


The script explained:
The **pooled** peaks will be intersected with the **individual** peak files for the replicates, to check for each pooled peak whether it overlaps a called peak in the individual replicate files.

For two replicates:

```bash
intersectBed -wao -a pooled_peaks.broadPeak -b donor1_peaks.broadPeak | cut -f 1,2,3,4,5,6,7,8,9,11 | intersectBed -wao -a - -b donor2_peaks.broadPeak | cut -f 1,2,3,4,5,6,7,8,9,10,12
```

For three replicates:

```bash
intersectBed -wao -a pooled_peaks.broadPeak -b donor1_peaks.broadPeak | cut -f 1,2,3,4,5,6,7,8,9,11 | intersectBed -wao -a - -b donor2_peaks.broadPeak | cut -f 1,2,3,4,5,6,7,8,9,10,12 intersectBed -wao -a - -b donor3_peaks.broadPeak | cut -f 1,2,3,4,5,6,7,8,9,10,11,13
```

For each additional replicate, the script adds the new replicate file to the command as `-b`: `intersectBed -wao -a - -b donorX_peaks.broadPeak | cut -f `, and adds an additional value to the penultimate value, since the number of columns in file `-a` has increased by one, and increase the last number by 1 (i.e. 9,10,11,13 becomes 9,10,11,12,14).

The output file will show the contents of the pooled peak file, with additional columns appended to the end, corresponding to the start coordinate of the peak overlap with the individual replicate. If the pooled peak does not overlap a peak within the replicate, a '-1' is shown. 

<img src="https://github.com/CebolaLab/Replicated-peaks/blob/main/Figures/Intersection-output.png" width="800">

This information can be used to obtain the number of individual replicates which the pooled peak overlaps, by counting the number of '-1' values (no overlap) per line.

A python script is then used to filter the file and is run using: `python filter.py -total [] -min [] -input peaks-overlap.bed -cols []` where -total is the total number of replicates, -min is the number of replicates required to define replicated peaks (default=2) and -cols is the number of columns in the bed files (one value required for all files).

```python
import argparse
parser = argparse.ArgumentParser()

#Arguments to the script include a comma-seperated list of peak files, the type of peaks and the output file name
parser.add_argument('-total', type=int, metavar='Number of replicates included', help='This should be the total number of replicates included in the experiment.')
parser.add_argument('-min', type=int, metavar='Number of minimum individual replicates required to define a replicated peak.', help='This should be the total number of replicates included in the experiment.',default=2)
parser.add_argument('-input',type=str, metavar='Input file from previous step')
parser.add_argument('-cols',type=str, metavar='Number of columns in the bed files.')

args = parser.parse_args()

data=open(args.input)
line=data.readline().split('\t')

out_file=open('replicated-peaks.bed','w')
for line in data.readlines():
    line=line.rstrip('\n')
    line2=line.split('\t')
    if args.total-sum('-1' in x for x in line2) >= args.min:
        out_file.write('\t'.join(line2[0:args.cols]) + '\t' + str(args.total-sum('-1' in x for x in line2)) + '\n')
out_file.close()
data.close()
```




