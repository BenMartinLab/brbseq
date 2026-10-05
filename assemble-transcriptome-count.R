library(GetoptLong)

quantification <- "pseudoalignment-quantification"

GetoptLong(
  "quantification=s", "Directory containing quantification counts from Kallisto quant",
)


cbind_vec2matrix <- function(list_vectors, row_names, col_names) {
  df_ = data.frame(do.call(cbind, list_vectors))
  colnames(df_) = col_names
  rownames(df_) = row_names
  return(df_)
}

list_dirs = list.dirs(quantification, recursive = F)
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
