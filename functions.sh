###############################################################################
# Extract sample names from samplesheet and build FASTQ files list
###############################################################################

collect_fastq_files() {
    local samplesheet="$1"
    local fastq_dir="$2"
    local -n out_array="$3"   # name reference to output array

    # Parse sample names (skip header, trim control chars)
    mapfile -t samples < <(
        awk -F',' 'NR>1 {gsub(/[[:cntrl:]]/, "", $1); print $1}' "$samplesheet"
    )

    # Build FASTQ list
    out_array=()
    for sample in "${samples[@]}"; do
        r1="${fastq_dir}/${sample}_R1.fq.gz"
        r2="${fastq_dir}/${sample}_R2.fq.gz"

        # Validate FASTQ files
        [[ -f "$r1" ]] || { echo "Missing FASTQ: $r1" >&2; exit 1; }
        [[ -f "$r2" ]] || { echo "Missing FASTQ: $r2" >&2; exit 1; }

        out_array+=("$r1" "$r2")
    done
}
