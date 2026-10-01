library(GetoptLong)

matrix <- "alignment/Solo.out/Gene/raw/matrix.mtx"
output <- "umi.counts.txt"

GetoptLong(
  "matrix=s", "Count matrix from STARsolo ()",
  "output=s", "Output count matrix in text"
)


library(data.table)
library(Matrix)

star_matrix.directory <- dirname("/home/christian/projects/data/file.txt")
star_matrix.file <- file(matrix, "r")
star_matrix <- as.data.frame(as.matrix(readMM(star_matrix.file)))
close(star_matrix.file)
feature.names = fread(paste0(star_matrix.directory, "features.tsv"), header = FALSE, stringsAsFactors = FALSE, data.table = FALSE)
barcode.names = fread(paste0(star_matrix.directory, "barcodes.tsv"), header = FALSE, stringsAsFactors = FALSE, data.table = FALSE)
colnames(star_matrix) <- barcode.names$V1
rownames(star_matrix) <- feature.names$V1
fwrite(star_matrix, file = output, sep = "\t", quote = FALSE, row.names = TRUE, col.names = TRUE)
