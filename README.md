# Defining replicated peaks (macs2())

This Github contains a short guide to defining replicated peaks from the output of macs2.

Replicated peaks are defined as peaks present in the **pooled** analysis and which are independently called in **two or more** biological replicates. 


The files required for this analysis include:

- macs2 pooled peaks
- macs2 peaks for individual samples

Please see the previous tutorials https://github.com/CebolaLab/ATAC-seq and https://github.com/CebolaLab/ChIPmentation for instructions on how to generate these files.


The pooled peaks will be intersected with the peak files for the individual replicates. 

Pooled peak.

For two replicates:

```bash
intersectBed -wao -a pooled_peaks.broadPeak -b donor1_peaks.broadPeak | cut -f 1,2,3,4,5,6,7,8,9,11 | intersectBed -wao -a - -b donor2_peaks.broadPeak | cut -f 1,2,3,4,5,6,7,8,9,10,12
```

For three replicates:

```bash
intersectBed -wao -a pooled_peaks.broadPeak -b donor1_peaks.broadPeak | cut -f 1,2,3,4,5,6,7,8,9,11 | intersectBed -wao -a - -b donor2_peaks.broadPeak | cut -f 1,2,3,4,5,6,7,8,9,10,12 intersectBed -wao -a - -b donor3_peaks.broadPeak | cut -f 1,2,3,4,5,6,7,8,9,10,11,13
```

For each additional replicate, add an additional column 

```bash
intersectBed -wao -a pooled_peaks.broadPeak -b donor2_peaks.broadPeak | cut -f 1,2,3,4,5,6,7,8,9,10,12
```

<img src="https://github.com/CebolaLab/Replicated-peaks/blob/main/Figures/Intersection-output.png" width="600">
