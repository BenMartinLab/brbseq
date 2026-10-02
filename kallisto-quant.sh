#!/bin/bash
#SBATCH --account=def-bmartin
#SBATCH --time=03:00:00
#SBATCH --cpus-per-task=24
#SBATCH --mem=24G
#SBATCH --output=kallisto-quant-%A_%a.out

set -euo pipefail

###############################################################################
# 0. Load modules on Alliance clusters
###############################################################################

if [[ -n "${CC_CLUSTER:-}" ]]; then
    module purge
    module load StdEnv/2023
    module load kallisto/0.51.1
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

###############################################################################
# 2. Help text
###############################################################################

show_help() {
    echo
    echo "Usage: $script_name [options] -- [extra args passed to kallisto quant]"
    echo
    echo "Wrapper options:"
    echo "  -S, --samplesheet FILE     Samplesheet CSV (default: samplesheet.csv)"
    echo "  -I, --sindex     INT       Sample index (default: SLURM_ARRAY_TASK_ID+1)"
    echo "  -F, --fastq-dir  DIR       FASTQ directory (default: fastq-demux)"
    echo "  -o, --output-dir DIR       Output directory (default: pseudoalignment-quantification)"
    echo "  -t, --threads    INT       Threads (default: SLURM_CPUS_PER_TASK)"
    echo "  -d, --dry-run              Print commands but do not execute"
    echo "  -h, --help                 Show this help"
    echo
    echo "Everything after '--' or any unknown option is passed directly to kallisto quant."
    echo
    echo "Do not specify FASTQ files; they are inferred from the samplesheet."
    echo
    echo "Example:"
    echo "  sbatch --cpus-per-task=8 --array=0-10 $script_name --samplesheet samples.csv -i kallisto/human.idx -l 550 -s 150 -b 5"
    echo "  $script_name --samplesheet samples.csv --sindex 3 -i kallisto/human.idx -l 550 -s 150 -b 5"
    echo
}

###############################################################################
# 3. Default values
###############################################################################

samplesheet="samplesheet.csv"
fastq_dir="fastq-demux"
output_dir="pseudoalignment-quantification"
threads="${SLURM_CPUS_PER_TASK:-1}"
dry_run=false

# SLURM array index → sample index
if [[ -n "${SLURM_ARRAY_TASK_ID:-}" ]]; then
    sindex=$((SLURM_ARRAY_TASK_ID + 1))
else
    sindex=1
fi

extra_parameters=()

###############################################################################
# 4. Manual argument parsing (safe, collision-free)
###############################################################################

extra_parameters=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -S|--samplesheet)
            samplesheet="$2"
            shift 2
            ;;
        -I|--sindex)
            sindex="$2"
            shift 2
            ;;
        -F|--fastq-dir)
            fastq_dir="$2"
            shift 2
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
# 5. Validate inputs
###############################################################################

if [[ ! -f "$samplesheet" ]]; then
    echo "Error: Samplesheet '$samplesheet' does not exist." >&2
    exit 1
fi

if ! [[ "$sindex" =~ ^[0-9]+$ ]]; then
    echo "Error: Sample index '$sindex' is not an integer." >&2
    exit 1
fi

if [[ ! -d "$fastq_dir" ]]; then
    echo "Error: FASTQ directory '$fastq_dir' does not exist." >&2
    exit 1
fi

###############################################################################
# 6. Extract sample name from samplesheet
###############################################################################

sample=$(awk -F',' -v idx="$sindex" 'NR==idx {print $1}' "$samplesheet")
sample="${sample%%[[:cntrl:]]}"

if [[ -z "$sample" ]]; then
    echo "Error: No sample found at index $sindex in $samplesheet." >&2
    exit 1
fi

###############################################################################
# 7. Logging + SLURM metadata + environment dump
###############################################################################

echo "------------------------------------------------------------"
echo "kallisto-quant.sh started at: $(date)"
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
# 8. Create output directory per sample
###############################################################################

sample_outdir="${output_dir}/${sample}"
mkdir -p "$sample_outdir"

###############################################################################
# 9. Build kallisto command
###############################################################################

cmd=(
    kallisto quant
    --output-dir="$sample_outdir"
    --threads="$threads"
    "${extra_parameters[@]}"
    "${fastq_dir}/${sample}_R1.fq.gz"
    "${fastq_dir}/${sample}_R2.fq.gz"
)

###############################################################################
# 10. Dry-run mode
###############################################################################

echo "Sample:      $sample"
echo "FASTQ dir:   $fastq_dir"
echo "Output dir:  $sample_outdir"
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
# 11. Execute kallisto
###############################################################################

"${cmd[@]}"
