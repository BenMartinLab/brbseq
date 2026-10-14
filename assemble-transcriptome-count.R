library(GetoptLong)

quantification <- "pseudoalignment-quantification"

GetoptLong(
  "quantification=s", "Directory containing quantification counts from Kallisto quant"
)


cbind_vec2matrix <- function(list_vectors, row_names, col_names) {
  df_ = data.frame(do.call(cbind, list_vectors))
  colnames(df_) = col_names
  rownames(df_) = row_names
  return(df_)
}

print(paste("Looking for abundance.tsv files in ", quantification))
list_dirs = list.dirs(quantification, recursive = F)
est_counts_l = list()
tpm_l = list()
sample_name_l = list()
for(i in 1:length(list_dirs)) {
  this_dir = list_dirs[[i]]
  abundance_file = paste0(this_dir, "/abundance.tsv")
  if (file.exists(abundance_file)) {
    abundance_tab = read.table(abundance_file, header=T)
    est_counts_l[[i]] = abundance_tab[["est_counts"]]
    tpm_l[[i]] = abundance_tab[["tpm"]]
    sample_name_l[[i]] = gsub("^[\\/]*", "", gsub(quantification, "", this_dir))
    print(paste("Abundance file", abundance_file, "found for sample", sample_name_l[[i]]))
  }
}

print(paste("Converting", length(sample_name_l), "abundance.tsv files to count matrix"))
df_counts = cbind_vec2matrix(est_counts_l, row_names = abundance_tab[["target_id"]], col_names = unlist(sample_name_l))
df_tpm = cbind_vec2matrix(tpm_l, row_names = abundance_tab[["target_id"]], col_names = unlist(sample_name_l))

counts <- paste0(quantification, "/counts.txt")
tpm <- paste0(quantification, "/tpm.counts.txt")
print(paste("Saving count matrix to", counts))
write.csv(df_counts, counts, quote=F)
print(paste("Saving TPM matrix to", counts))
write.csv(df_tpm, tpm, quote=F)
