# BRB-seq data analysis

This repository contains scripts to analyse BRB-seq data using the pipeline recommended by [Alithea Genomics](https://alitheagenomics.com/technology/brb-seq/) on Alliance Canada servers.

To install the scripts on Alliance Canada servers and download genomes, see [INSTALL.md](INSTALL.md)

### Steps

1. [Samplesheet](#samplesheet)
2. [Transfer data to scratch](#transfer-data-to-scratch)
3. [Prepare working environment](#prepare-working-environment)
   1. [Set additional variables](#set-additional-variables)
4. [Convert samplesheet to other formats](#convert-samplesheet-to-other-formats)
5. [Sequencing data quality check](#sequencing-data-quality-check)
6. [Pseudo-alignment and transcriptome quantification](#pseudo-alignment-and-transcriptome-quantification)
   1. [Demultiplex FASTQ files](#demultiplex-fastq-files)
   2. [Quantify transcript abundance](#quantify-transcript-abundance)
   3. [Assemble transcriptome counts](#assemble-transcriptome-counts)
7. [Alignment and gene quantification](#alignment-and-gene-quantification)
   1. [Aligning to the reference genome and generation of count matrices](#aligning-to-the-reference-genome-and-generation-of-count-matrices)
   2. [Generating the count matrix from .mtx file](#generating-the-count-matrix-from-mtx-file)
   3. [Generating the read count matrix with per-sample stats (Optional)](#generating-the-read-count-matrix-with-per-sample-stats-optional)
   4. [Demultiplexing bam files (Optional)](#Demultiplexing-bam-files-Optional)

## Samplesheet

* Here is an example of a samplesheet file [samplesheet.csv](samplesheet.csv).

You must create a samplesheet with at least the following columns in CSV format.

```text
sample    Sample name
barcode   Barcode that identifies this sample
```

> [!NOTE]
> `read_structure_*` are only partially supported. If you need them, contact your bio-informaticien.

## Transfer data to scratch

You will need to transfer the following files on the server in the `scratch` folder.

* Samplesheet file.
* FASTQ files.
* Genome files (FASTA and GTF). See [Genomes](https://github.com/BenMartinLab/genomes).
    * Copy `star` folder for your genome.
    * Copy `kallisto` folder for your genome.
* Any additional files that are needed for your analysis.

There are many ways to transfer data to the server. Here are some suggestions.

* Use an FTP software like [WinSCP](https://winscp.net) (Windows), [Cyberduck](https://cyberduck.io) (Mac), [FileZilla](https://filezilla-project.org).
* Use command line tools like `rsync` or `scp`.

## Prepare working environment

Add BRB-seq scripts folder to your PATH.

```shell
export PATH=/project/def-bmartin/scripts/brbseq:$PATH
```

### Set additional variables

> [!IMPORTANT]
> Change `samplesheet.csv` by your actual samplesheet filename.

```shell
samplesheet=samplesheet.csv
```

```shell
samples_array=$(awk -F ',' \
    'NR > 1 && !seen[$1] {ln++; seen[$1]++} END {print "0-"ln-1}' \
    "$samplesheet")
```

> [!IMPORTANT]
> Change `mylibrary` by the actual filename prefix for FASTQ files.

```shell
library=mylibrary
```

> [!IMPORTANT]
> Change `hg38-spike-dm6` by your actual genome name.

```shell
genome=hg38-spike-dm6
```

> [!IMPORTANT]
> Change `dm6` by your actual spike-in genome name.

```shell
spike=dm6
```

## Convert samplesheet to other formats

The samplesheet file must be converted to other formats to run the pipeline. Simply run the following command.

```shell
convert-samplesheet.py $samplesheet
```

## Sequencing data quality check

```shell
sbatch fastqc.sh ./*.fastq.gz
```

## Pseudo-alignment and transcriptome quantification

### Demultiplex FASTQ files

```shell
sbatch fqtk-demux.sh \
  -i "${library}_R1.fastq.gz" "${library}_R2.fastq.gz" \
  -r 14B14M 90T \
  -s "$(basename samplesheet .csv).fqtk_metadata.tsv"
```

### Quantify transcript abundance

```shell
sbatch --array=$samples_array kallisto-quant.sh \
  -S $samplesheet \
  -i kallisto/$genome.idx \
  -l 550 \
  -s 150 \
  -b 5
```

Using `kallisto bus`.

```shell
sbatch kallisto-bus.sh \
  -S $samplesheet \
  -i kallisto/$genome.idx \
  -x BULK \
  --paired
```

### Assemble transcriptome counts

```shell
sbatch assemble-transcriptome-count.sh
```

## Alignment and gene quantification

### Aligning to the reference genome and generation of count matrices

```shell
sbatch star.sh --runMode alignReads \
  --outSAMmapqUnique 60 \
  --outSAMunmapped Within \
  --soloStrand Forward \
  --quantMode GeneCounts \
  --genomeDir star \
  --soloType CB_UMI_Simple \
  --soloCBstart 1 \
  --soloCBlen 14 \
  --soloUMIstart 15 \
  --soloUMIlen 14 \
  --soloUMIdedup NoDedup 1MM_Directional \
  --soloCellFilter None \
  --soloCBwhitelist "$(basename samplesheet .csv).whitelist.txt" \
  --soloBarcodeReadLength 0 \
  --soloFeatures Gene \
  --outSAMattributes NH HI nM AS CR UR CB UB GX GN sS sQ sM \
  --outFilterMultimapNmax 1 \
  --readFilesCommand zcat \
  --outSAMtype BAM SortedByCoordinate \
  --readFilesIn "${library}_R2.fastq.gz" "${library}_R1.fastq.gz"
```

### Generating the count matrix from .mtx file

```shell
sbatch count-matrix.sh
```

### Generating the read count matrix with per-sample stats (Optional)

```shell
sbatch fast-read-counter.sh \
  --bam alignment/Aligned.sortedByCoord.out.bam \
  --gtf $genome.idx \
  --umi-dedup none \
  --barcodeFile "$(basename samplesheet .csv).fastreadcounter.tsv"
```

### Demultiplexing bam files (Optional)

```shell
sbatch --array=$samples_array picard-filter-sam-reads.sh
  I=alignment/Aligned.sortedByCoord.out.bam \
  FILTER=includeTagValues \
  TAG=CR \
  TAG_VALUE=${tag_value}
```
