###############################################################################
# Extract sample names from samplesheet
###############################################################################

collect_samples() {
    local samplesheet="$1"
    local -n out_samples="$2"

    mapfile -t out_samples < <(
        awk -F',' 'NR>1 {gsub(/[[:cntrl:]]/, "", $1); print $1}' "$samplesheet"
    )
}

###############################################################################
# Build FASTQ files list
###############################################################################

collect_fastq_files() {
    local fastq_dir="$1"
    local -n sample_array="$2"
    local -n out_fastqs="$3"

    out_fastqs=()

    for sample in "${sample_array[@]}"; do
        local r1="${fastq_dir}/${sample}.R1.fq.gz"
        local r2="${fastq_dir}/${sample}.R2.fq.gz"

        [[ -f "$r1" ]] || { echo "Missing FASTQ: $r1" >&2; exit 1; }
        [[ -f "$r2" ]] || { echo "Missing FASTQ: $r2" >&2; exit 1; }

        out_fastqs+=("$r1" "$r2")
    done
}
