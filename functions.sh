###############################################################################
# Extract sample names from samplesheet
###############################################################################

collect_samples() {
    local samplesheet="$1"
    local -n out_samples="$2"

    sample_column=$(awk -F ',' \
        'NR == 1 {for (i = 1; i <= NF; i++) if (gensub(/[[:cntrl:]\n]/, "", "g", $i) == "sample") {print i; exit(0)}}' \
        "$samplesheet")
    mapfile -t out_samples < <(
        awk -F ',' -v sample_column="${sample_column}" \
        'NR>1 {gsub(/[[:cntrl:]]/, "", $sample_column); print $sample_column}' "$samplesheet"
    )
}
