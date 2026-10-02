#!/bin/bash
#SBATCH --account=def-bmartin
#SBATCH --time=12:00:00
#SBATCH --cpus-per-task=48
#SBATCH --mem=120G
#SBATCH --output=star-%A.out

set -euo pipefail

###############################################################################
# Load modules on Alliance clusters
###############################################################################

if [[ -n "${CC_CLUSTER:-}" ]]; then
    module purge
    module load StdEnv/2023
    module load star/2.7.11b
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
    echo "Usage: $script_name [options] -- [extra args passed to STAR]"
    echo
    echo "Wrapper options:"
    echo "  --outFileNamePrefix STR    Output filename prefix (default: ./alignment)"
    echo "  --outTmpDir      DIR       Output temporary directory (default: SLURM_TMPDIR)"
    echo "  --runThreadN     INT       Threads (default: SLURM_CPUS_PER_TASK)"
    echo "  --outBAMsortingThreadN INT   Threads for sorting BAM (default: SLURM_CPUS_PER_TASK)"
    echo "  -d, --dry-run              Print commands but do not execute"
    echo "  -h, --help                 Show this help"
    echo
    echo "Everything after '--' or any unknown option is passed directly to STAR."
    echo
    echo "Example:"
    echo "  sbatch --cpus-per-task=48 $script_name --runMode alignReads --readFilesIn library_R2.fastq.gz library_R1.fastq.gz"
    echo "  $script_name --runMode alignReads --runThreadN 8 --readFilesIn library_R2.fastq.gz library_R1.fastq.gz"
    echo
}

###############################################################################
# Default values
###############################################################################

output_prefix=./alignment
output_dir_tmp=${SLURM_TMPDIR:-}
threads=${SLURM_CPUS_PER_TASK:-1}
bam_sorting_threads=${SLURM_CPUS_PER_TASK:-1}

###############################################################################
# Manual argument parsing (safe, collision-free)
###############################################################################

extra_parameters=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --outFileNamePrefix)
            output_prefix="$2"
            shift 2
            ;;
        --outFileNamePrefix=*)
            output_prefix="${1#--outFileNamePrefix=}"
            shift
            ;;
        --outTmpDir)
            output_dir_tmp="$2"
            shift 2
            ;;
        --outTmpDir=*)
            output_dir_tmp="${1#--outTmpDir=}"
            shift
            ;;
        --runThreadN)
            threads="$2"
            shift 2
            ;;
        --runThreadN=*)
            threads="${1#--runThreadN=}"
            shift
            ;;
        --outBAMsortingThreadN)
            bam_sorting_threads="$2"
            shift 2
            ;;
        --outBAMsortingThreadN=*)
            bam_sorting_threads="${1#--outBAMsortingThreadN=}"
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
            # Unknown short option → passthrough to STAR
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
# Use outTmpDir parameter only if specified or if SLURM is used, otherwise use STAR default value.
###############################################################################

if [[ -n "$output_dir_tmp" ]]
then
  extra_parameters=("--outTmpDir" "$output_dir_tmp" "${extra_parameters[@]}")
fi

###############################################################################
# Logging + SLURM metadata + environment dump
###############################################################################

echo "------------------------------------------------------------"
echo "star.sh started at: $(date)"
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
# Build STAR command
###############################################################################

cmd=(
    STAR
    --outFileNamePrefix="$output_prefix"
    --runThreadN "$threads"
    --outBAMsortingThreadN "$bam_sorting_threads"
    "${extra_parameters[@]}"
)

###############################################################################
# Dry-run mode
###############################################################################

echo "Out prefix:  $output_prefix"
echo "Out tmp dir: ${output_dir_tmp:-}"
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
# Execute STAR
###############################################################################

"${cmd[@]}"
