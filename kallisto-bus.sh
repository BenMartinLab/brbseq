#!/bin/bash
#SBATCH --account=def-bmartin
#SBATCH --time=03:00:00
#SBATCH --cpus-per-task=24
#SBATCH --mem=24G
#SBATCH --output=kallisto-bus-%A.out

set -euo pipefail

###############################################################################
# Load modules on Alliance clusters
###############################################################################

if [[ -n "${CC_CLUSTER:-}" ]]; then
    module purge
    module load StdEnv/2023
    module load kallisto/0.51.1
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
    echo "Usage: $script_name [options] -- [extra args passed to kallisto bus]"
    echo
    echo "Wrapper options:"
    echo "  -S, --samplesheet FILE     Samplesheet CSV (default: samplesheet.csv)"
    echo "  -F, --fastq-dir  DIR       FASTQ directory (default: fastq-demux)"
    echo "  -o, --output-dir DIR       Output directory (default: pseudoalignment-quantification)"
    echo "  -t, --threads    INT       Threads (default: SLURM_CPUS_PER_TASK)"
    echo "  -d, --dry-run              Print commands but do not execute"
    echo "  -h, --help                 Show this help"
    echo
    echo "Everything after '--' or any unknown option is passed directly to kallisto bus."
    echo
    echo "Do not specify FASTQ files; they are inferred from the samplesheet."
    echo
    echo "Example:"
    echo "  sbatch --cpus-per-task=8 --array=0-10 $script_name --samplesheet samples.csv -i kallisto/human.idx -l 550 -s 150 -b 5"
    echo "  $script_name --samplesheet samples.csv --sindex 3 -i kallisto/human.idx -l 550 -s 150 -b 5"
    echo
}

###############################################################################
# Default values
###############################################################################

samplesheet="samplesheet.csv"
fastq_dir="fastq-demux"
output_dir="pseudoalignment-quantification"
threads="${SLURM_CPUS_PER_TASK:-1}"
dry_run=false

###############################################################################
# Manual argument parsing (safe, collision-free)
###############################################################################

extra_parameters=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -S|--samplesheet)
            samplesheet="$2"
            shift 2
            ;;
        --samplesheet=*)
            samplesheet="${1#--samplesheet=}"
            shift
            ;;
        -F|--fastq-dir)
            fastq_dir="$2"
            shift 2
            ;;
        --fastq-dir=*)
            fastq_dir="${1#--fastq-dir=}"
            shift
            ;;
        -o|--output-dir)
            output_dir="$2"
            shift 2
            ;;
        --output-dir=*)
            output_dir="${1#--output-dir=}"
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
            # Unknown short option → passthrough to kallisto
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
# Validate inputs
###############################################################################

if [[ ! -f "$samplesheet" ]]; then
    echo "Error: Samplesheet '$samplesheet' does not exist." >&2
    exit 1
fi

if [[ ! -d "$fastq_dir" ]]; then
    echo "Error: FASTQ directory '$fastq_dir' does not exist." >&2
    exit 1
fi

###############################################################################
# Get FASTQ files list
###############################################################################

source "${script_dir}/functions.sh"
samples=()
collect_samples "$samplesheet" samples
fastq_files=()
collect_fastq_files "$fastq_dir" samples fastq_files

###############################################################################
# Logging + SLURM metadata + environment dump
###############################################################################

echo "------------------------------------------------------------"
echo "kallisto-bus.sh started at: $(date)"
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
# Build kallisto command
###############################################################################

cmd=(
    kallisto bus
    --output-dir="$output_dir"
    --threads="$threads"
    "${extra_parameters[@]}"
    "${fastq_files[@]}"
)

###############################################################################
# Dry-run mode
###############################################################################

echo "FASTQ dir:   $fastq_dir"
echo "Output dir:  $output_dir"
echo "Threads:     $threads"
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
# Execute kallisto
###############################################################################

"${cmd[@]}"
