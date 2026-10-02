#!/bin/bash
#SBATCH --account=def-bmartin
#SBATCH --time=03:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
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
script_dir="$(dirname "$script_path")"

###############################################################################
# Help text
###############################################################################

show_help() {
    echo
    echo "Usage: $script_name [options] -- [extra args passed to picard FilterSamReads]"
    echo
    echo "Wrapper options:"
    echo "  -s, --samplesheet FILE     Samplesheet CSV (default: samplesheet.csv)"
    echo "  -i, --index      INT       Sample index (default: SLURM_ARRAY_TASK_ID+1)"
    echo "  -O, --OUTPUT     FILE      Output file (default: alignment/bam-demux/\${sample}.bam)"
    echo "  -d, --dry-run              Print commands but do not execute"
    echo "  -h, --help                 Show this help"
    echo
    echo "Everything after '--' or any unknown option is passed directly to picard FilterSamReads."
    echo
    echo "Example:"
    echo "  sbatch --cpus-per-task=8 $script_name --bam alignment/Aligned.sortedByCoord.out.bam --gtf human.idx --barcodeFile barcodes-frc.txt"
    echo "  $script_name --bam alignment/Aligned.sortedByCoord.out.bam --gtf human.idx --barcodeFile barcodes-frc.txt"
    echo
}

###############################################################################
# Default values
###############################################################################

samplesheet=samplesheet.csv
index=${SLURM_ARRAY_TASK_ID}
index=$((index+1))
dry_run=false

###############################################################################
# Manual argument parsing (safe, collision-free)
###############################################################################

extra_parameters=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -s|--samplesheet)
            samplesheet="$2"
            shift 2
            ;;
        --SAMPLESHEET=*)
            samplesheet="${1#--SAMPLESHEET=}"
            shift
            ;;
        -i|--index)
            index="$2"
            shift 2
            ;;
        --INDEX=*)
            index="${1#--INDEX=}"
            shift
            ;;
        -O|--OUTPUT)
            output="$2"
            shift 2
            ;;
        -O=*)
            output="${1#-O=}"
            shift
            ;;
        --OUTPUT=*)
            output="${1#--OUTPUT=}"
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
# Get samples and FASTQ files list
###############################################################################

source "${script_dir}/functions.sh"
samples=()
collect_samples "$samplesheet" samples
sample="${samples[$((sindex-1))]}"

###############################################################################
# Set default output file
###############################################################################

if [[ -z "${output:-}" ]]; then
  output="alignment/bam-demux/${sample}.bam"
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
    java -jar "$EBROOTPICARD"/picard.jar
    O="output_dir"
    "${extra_parameters[@]}"
)

###############################################################################
# Dry-run mode
###############################################################################

echo "Samplesheet:  $samplesheet"
echo "Sample index: $index"
echo "Output file:  $output"
echo "Dry-run:     $dry_run"
echo
echo "Command:"
printf "  %q " "${cmd[@]}"
echo
echo

if [[ "$dry_run" == true ]]; then
    echo "Dry-run mode enabled — command not executed."
    exit 0
fi

###############################################################################
# Execute picard FilterSamReads
###############################################################################

"${cmd[@]}"
