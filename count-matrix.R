library(GetoptLong)

samplesheet <- "samplesheet.csv"
matrix <- "alignment/Solo.out/Gene/raw/umiDedup-NoDedup.mtx"
output <- "alignment/umi.counts.txt"

GetoptLong(
  "samplesheet=s", "Samplesheet containing barcodes",
  "matrix=s", "Count matrix from STARsolo",
  "output=s", "Output count matrix in text"
)


library(data.table)
library(Matrix)
library(dplyr)

star_matrix.directory <- dirname(matrix)
feature <- paste0(star_matrix.directory, "/features.tsv")
barcode <- paste0(star_matrix.directory, "/barcodes.tsv")

print(paste("Reading count matrix", matrix))
star_matrix.file <- file(matrix, "r")
star_matrix <- as.data.frame(as.matrix(readMM(star_matrix.file)))
close(star_matrix.file)
print(paste("Reading features", feature))
feature.names = fread(feature, header = FALSE, stringsAsFactors = FALSE, data.table = FALSE)
print(paste("Reading barcodes", barcode))
barcode.names = fread(barcode, header = FALSE, stringsAsFactors = FALSE, data.table = FALSE)
barcode.names$barcode <- barcode.names$V1
print(paste("Converting barcodes to sample names using samplesheet", samplesheet))
samplesheet.data <- read.csv(samplesheet)
barcode.names <- barcode.names %>% left_join(samplesheet.data, by = join_by(barcode)) %>% mutate(sample = coalesce(sample, barcode))
colnames(star_matrix) <- barcode.names$sample
rownames(star_matrix) <- feature.names$V1
print(paste("Saving count matrix to", output))
fwrite(star_matrix, file = output, sep = "\t", quote = FALSE, row.names = TRUE, col.names = TRUE)
