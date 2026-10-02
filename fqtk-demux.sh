#!/bin/bash
#SBATCH --account=def-bmartin
#SBATCH --time=03:00:00
#SBATCH --cpus-per-task=24
#SBATCH --mem=24G
#SBATCH --output=fqtk-demux-%A.out

set -euo pipefail

###############################################################################
# 0. Load modules on Alliance clusters
###############################################################################

if [[ -n "${CC_CLUSTER:-}" ]]; then
    module purge
    module load StdEnv/2023
    module load rust/1.95.0
    echo
fi

###############################################################################
# 1. Script name detection (SLURM-friendly)
###############################################################################

script_path="${BASH_SOURCE[0]}"
if [[ "$(basename "$script_path")" == "slurm_script" && -n "${SLURM_JOB_ID:-}" ]]; then
    script_path="$(scontrol show job "$SLURM_JOB_ID" \
        | awk -F= '/Command=/ {print $2; exit}')"
fi
script_name="$(basename "$script_path")"
script_path=$(dirname "$script_path")

###############################################################################
# 2. Help text
###############################################################################

show_help() {
    echo
    echo "Usage: $script_name [options] -- [extra args passed to fqtk demux]"
    echo
    echo "Wrapper options:"
    echo "  -o, --output     DIR       Output directory (default: fastq-demux)"
    echo "  -t, --threads    INT       Threads (default: SLURM_CPUS_PER_TASK)"
    echo "  -d, --dry-run              Print commands but do not execute"
    echo "  -h, --help                 Show this help"
    echo
    echo "Everything after '--' or any unknown option is passed directly to fqtk demux."
    echo
    echo "Example:"
    echo "  sbatch --cpus-per-task=8 $script_name -i library_R1.fastq.gz library_R1_R2.fastq.gz -r 14B14M 90T -s barcode_ref.txt"
    echo "  $script_name --threads 8 -i library_R1.fastq.gz library_R1_R2.fastq.gz -r 14B14M 90T -s barcode_ref.txt"
    echo
}

###############################################################################
# 3. Default values
###############################################################################

output_dir=fastq-demux
threads="${SLURM_CPUS_PER_TASK:-1}"
dry_run=false

###############################################################################
# 4. Manual argument parsing (safe, collision-free)
###############################################################################

extra_parameters=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--output)
            output_dir="$2"
            shift 2
            ;;
        --output=*)
            output_dir="${1#--output=}"
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
            # Unknown short option → passthrough to fqtk demux
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
# 5. Logging + SLURM metadata + environment dump
###############################################################################

echo "------------------------------------------------------------"
echo "fqtk-demux.sh started at: $(date)"
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
# 6. Build fqtk demux command
###############################################################################

cmd=(
    "${script_path}/fqtk/fqtk" demux \
    --threads "$threads" \
    --output "$output_dir" \
    "${extra_parameters[@]}"
)

###############################################################################
# 7. Dry-run mode
###############################################################################

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
# 11. Execute fqtk demux
###############################################################################

"${cmd[@]}"
