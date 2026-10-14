#!/bin/bash
#SBATCH --account=def-bmartin
#SBATCH --time=12:00:00
#SBATCH --cpus-per-task=16
#SBATCH --mem=30G
#SBATCH --output=picard-filter-sam-reads-%A.out

set -euo pipefail

###############################################################################
# Load modules on Alliance clusters
###############################################################################

if [[ -n "$CC_CLUSTER" ]]
then
  module purge
  module load StdEnv/2023
  module load picard/3.1.0
  echo
fi

###############################################################################
# Script name detection (SLURM-friendly)
###############################################################################

script_path="${BASH_SOURCE[0]}"
if [[ "$(basename "$script_path")" == "slurm_script" && -n "${SLURM_JOB_ID:-}" ]]; then
    script_path="$(scontrol show job "$SLURM_JOB_ID" \
        | awk -F= '/Command=/ {print $2; exit}')"
fi
script_name="$(basename "$script_path")"

###############################################################################
# Help text
###############################################################################

show_help() {
    echo
    echo "Usage: $script_name [options] -- [extra args passed to picard FilterSamReads]"
    echo
    echo "Wrapper options:"
    echo "  -b, --barcode   FILE     Bacode file (default: samplesheet.fastreadcounter.tsv)"
    echo "  -I, --INPUT     FILE     Input BAM file (default: alignment/Aligned.sortedByCoord.out.bam)"
    echo "  -O, --OUTPUT    DIR      Output directory (default: alignment/bam-demux)"
    echo "  -d, --dry-run            Print commands but do not execute"
    echo "  -t, --threads   INT      Threads (default: SLURM_CPUS_PER_TASK)"
    echo "  -h, --help               Show this help"
    echo
    echo "Everything after '--' or any unknown option is passed directly to picard FilterSamReads."
    echo
    echo "Do not specify TAG_VALUE arguments; they are inferred from the samplesheet."
    echo
    echo "Example:"
    echo "  sbatch --cpus-per-task=8 $script_name I=alignment/Aligned.sortedByCoord.out.bam FILTER=includeTagValues TAG=CR"
    echo "  $script_name I=alignment/Aligned.sortedByCoord.out.bam FILTER=includeTagValues TAG=CR"
    echo
}

###############################################################################
# Default values
###############################################################################

barcode=samplesheet.fastreadcounter.tsv
input_file=alignment/Aligned.sortedByCoord.out.bam
output_dir=alignment/bam-demux
threads="${SLURM_CPUS_PER_TASK:-1}"
dry_run=false

###############################################################################
# Manual argument parsing (safe, collision-free)
###############################################################################

extra_parameters=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -b|--barcode)
            barcode="$2"
            shift 2
            ;;
        --BARCODE=*)
            barcode="${1#--BARCODE=}"
            shift
            ;;
        -I|--INPUT)
            input_file="$2"
            shift 2
            ;;
        I=*)
            input_file="${1#-I=}"
            shift
            ;;
        INPUT=*)
            input_file="${1#--INPUT=}"
            shift
            ;;
        -O|--OUTPUT)
            output_dir="$2"
            shift 2
            ;;
        O=*)
            output_dir="${1#-O=}"
            shift
            ;;
        OUTPUT=*)
            output_dir="${1#--OUTPUT=}"
            shift
            ;;
        -t|--threads)
            threads="$2"
            shift 2
            ;;
        --threads=*)
            threads="${1#--threads=}"
            shift
            ;;
        -d|--dry-run)
            dry_run=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        --)
            shift
            extra_parameters+=("$@")
            break
            ;;
        --*=*)
            # Long option with equals: --option=value
            extra_parameters+=("$1")
            shift
            ;;
        -*)
            # Unknown short option → passthrough to picard FilterSamReads
            extra_parameters+=("$1")
            shift
            ;;
        *)
            # Positional argument → passthrough
            extra_parameters+=("$1")
            shift
            ;;
    esac
done

###############################################################################
# Copy input to local scratch, if possible
###############################################################################

if [[ -n "${SLURM_TMPDIR:-}" ]]; then
    input_tmp_file="${SLURM_TMPDIR}/$(basename "$input_file")"
    echo "Copying input file $input_file to $input_tmp_file for faster reading"
    cp "$input_file" "$input_tmp_file"
    input_file="$input_tmp_file"
fi

###############################################################################
# Logging + SLURM metadata + environment dump
###############################################################################

echo "------------------------------------------------------------"
echo "picard-filter-sam-reads.sh started at: $(date)"
echo "Host: $(hostname)"
echo "User: $USER"
echo "Script: $script_name"
echo
echo "SLURM metadata:"
echo "  Job ID:        ${SLURM_JOB_ID:-N/A}"
echo "  Array Task ID: ${SLURM_ARRAY_TASK_ID:-N/A}"
echo "  CPUs:          ${SLURM_CPUS_PER_TASK:-N/A}"
echo "  Node:          ${SLURM_NODELIST:-N/A}"
echo
echo "Environment dump:"
env | sort
echo "------------------------------------------------------------"
echo

###############################################################################
# Build picard FilterSamReads command
###############################################################################

cmd=(
    java -jar "$EBROOTPICARD"/picard.jar FilterSamReads
    INPUT="$input_file"
    "${extra_parameters[@]}"
)

###############################################################################
# Dry-run mode
###############################################################################

echo "Barcode file:  $barcode"
echo "Input file:    $input_file"
echo "Output dir:    $output_dir"
echo "Threads:       $threads"
echo "Dry-run:       $dry_run"
echo
echo

###############################################################################
# Execute picard FilterSamReads
###############################################################################

mkdir -p "${output_dir}"
if [[ "$dry_run" == true ]]; then
    echo "Dry-run mode enabled — command not executed."
    dry_run_parameters=("--dry-run")
fi
parallel -j "$threads" \
    --colsep '\t' \
    "${dry_run_parameters[@]}" \
    "${cmd[@]}" O="${output_dir}/{2}.bam" "TAG_VALUE={1}" \
    :::: "$barcode"
