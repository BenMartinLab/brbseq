# BRB-seq data analysis

This repository contains scripts to analyse BRB-seq data using the pipeline recommended by [Alithea Genomics](https://alitheagenomics.com/technology/brb-seq/) on Alliance Canada servers.

To install the scripts on Alliance Canada servers and download genomes, see [INSTALL.md](INSTALL.md)

### Steps

1. [Samplesheet](#samplesheet)
2. [Transfer data to scratch](#transfer-data-to-scratch)
3. [Prepare working environment](#prepare-working-environment)
   1. [Set additional variables](#set-additional-variables)
4. [Sequencing data quality check](#sequencing-data-quality-check)
5. [Pseudo-alignment and transcriptome quantification](#pseudo-alignment-and-transcriptome-quantification)
   1. [Demultiplex FASTQ files](#demultiplex-fastq-files)
   2. [Quantify transcript abundance](#quantify-transcript-abundance)
   3. [Assemble transcriptome counts](#assemble-transcriptome-counts)
6. [Alignment and gene quantification](#alignment-and-gene-quantification)
   1. [Create barcode whitelist](#create-barcode-whitelist)
   2. [Aligning to the reference genome and generation of count matrices](#aligning-to-the-reference-genome-and-generation-of-count-matrices)
   3. [Generating the count matrix from .mtx file](#generating-the-count-matrix-from-mtx-file)
   4. [Generating the read count matrix with per-sample stats (Optional)](#generating-the-read-count-matrix-with-per-sample-stats-optional)
   5. [Demultiplexing bam files (Optional)](#Demultiplexing-bam-files-Optional)

## Samplesheet

> [!WARNING]
> Documentation needs to be changed.

See [Samplesheet for RNA-seq pipeline](https://nf-co.re/rnaseq/3.22.2/docs/usage/#samplesheet-input) for details.

> [!IMPORTANT]
> Sample names should be "\$group_REP\$replicate" where "\$group" is usually the condition and "\$replicate" is a number (examples: DMSO_REP1, PF9363_REP2) [Read the 'NB' note in this link](https://nf-co.re/rnaseq/3.22.2/docs/usage/#full-samplesheet)

[Here is an example of a samplesheet file](samplesheet.csv)

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
> Change `mylibrary` by the actual filename prefix for FASTQ files.

```shell
library=mylibrary
```

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
> Change `hg38-spike-dm6` by your actual genome name.

```shell
genome=hg38-spike-dm6
```

> [!IMPORTANT]
> Change `dm6` by your actual spike-in genome name.

```shell
spike=dm6
```

## Sequencing data quality check

```shell
sbatch fastqc.sh -o fastqc ./*.fastq.gz
```

## Pseudo-alignment and transcriptome quantification

### Demultiplex FASTQ files

```shell
sbatch fqtk-demux.sh \
  -i "${library}_R1.fastq.gz" "${library}_R2.fastq.gz" \
  -r 14B14M 90T \
  -s barcode_ref.txt
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

```r
# R script for collecting transcriptome data
 
cbind_vec2matrix <- function(list_vectors, row_names, col_names) {
  df_ = data.frame(do.call(cbind, list_vectors))
  colnames(df_) = col_names
  rownames(df_) = row_names
  return(df_)
}
 
list_dirs = list.dirs("quant/", recursive = F)
est_counts_l = list()
tmp_l = list()
sample_name_l = list()
for(i in 1:length(list_dirs)) {
  this_dir = list_dirs[[i]]
  abundance_file = paste0(this_dir, '/abundance.tsv')
  if (file.exists(abundance_file)) {
    abundance_tab = read.table(abundance_file, header=T)
    est_counts_l[[i]] = abundance_tab[['est_counts']]
    tmp_l[[i]] = abundance_tab[['tpm']]
    sample_name_l[[i]] = gsub("^\\\\/", "", gsub("$in_dir", '', this_dir))
  }
}
 
df_counts = cbind_vec2matrix(est_counts_l, row_names = abundance_tab[["target_id"]], col_names = unlist(sample_name_l))
df_tpm = cbind_vec2matrix(tmp_l, row_names = abundance_tab[["target_id"]], col_names = unlist(sample_name_l))
 
lib_name = gsub("_kallisto_out","","$in_dir")
write.csv(df_counts, paste0(lib_name,".counts.txt"), quote=F)
write.csv(df_tpm, paste0(lib_name,".tpm.counts.txt"), quote=F)
```

## Alignment and gene quantification

### Create barcode whitelist

```shell
samplesheet-to-barcodes.sh -s $samplesheet
```

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
  --soloCBwhitelist barcodes.txt \
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
FastReadCounter-1.0.jar \
  --bam ${bam_path} \
  --gtf ${gtf_file} \
  --umi-dedup none \
  --barcodeFile ${barcode_file} \
  -o ${output_folder}
```

### Demultiplexing bam files (Optional)

```shell
java -jar /path/to/picard.jar FilterSamReads \
  I=${input_bam} \
  FILTER=includeTagValues \
  TAG=CR \
  TAG_VALUE=${tag_value} \
  O=${demultiplexed_bam_out_dir}/${sample_id}.bam
```