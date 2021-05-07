
declare -i n
n=$1

pooled=$2

list=$3
IFS=',' read -r -a array <<< "$list"

intersectBed -wao -a $pooled -b ${array[0]} | cut -f 1,2,3,4,5,6,7,8,9,10,12 > peaks-overlap.bed

min=1
max=11
extra=13

#range=$(seq 1 11)+12

for x in $(seq 1 $n)
do
     intersectBed -wao -a peaks-overlap.bed "${array[$x]}" | cut -f echo$($(seq 1 $max) $extra) > peaks-overlap.bed
done

for x in $(seq 1 $n); do echo "${array[0]}";done

#intersectBed -wao -a $pooled -b donor1_peaks.broadPeak | cut -f 1,2,3,4,5,6,7,8,9,11 | intersectBed -wao -a - -b donor2_peaks.broadPeak | cut -f 1,2,3,4,5,6,7,8,9,10,12

