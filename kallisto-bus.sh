#!/bin/bash
#SBATCH --account=def-bmartin
#SBATCH --time=03:00:00
#SBATCH --cpus-per-task=24
#SBATCH --mem=24G
#SBATCH --output=kallisto-bus-%A.out

# exit when any command fails
set -e

if [[ -n "$CC_CLUSTER" ]]
then
  module purge
  module load StdEnv/2023
  module load kallisto/0.51.1
  echo
fi

script_name=$(basename "${BASH_SOURCE[0]}")
if [[ "$script_name" == "slurm_script" ]] && [[ -n "$SLURM_JOB_ID" ]]
then
  slurm_command=$(scontrol show job "$SLURM_JOB_ID" | awk -F '=' '$0 ~ /Command=/ {print $2; exit}')
  script_name=$(basename "$slurm_command")
fi

samplesheet=samplesheet.csv
fastq_dir=fastq-demux
output_dir=pseudoalignment-quantification
threads=${SLURM_CPUS_PER_TASK:-1}

# Usage function
usage() {
  echo
  echo "Usage: $script_name [-S <samplesheet.csv>] [-I <index>] [-F <fastq_dir>] [-h]"
  echo "  -S, --samplesheet: Samplesheet file (default: samplesheet.csv)"
  echo "  -F, --fdir: Directory where FASTQ files are stored (default: fastq-demux)"
  echo "  -h, --help: Show this help"
  echo ""
  echo "Any additional parameters will be passed to kallisto bus"
  echo ""
  echo "Do not specify --batch parameter or FASTQ input files as they will be set from the samplesheet."
}

# Parsing arguments.
while [ "$1" != "" ]; do
  case $1 in
    -S | --samplesheet)	shift
      samplesheet=$1
      ;;
    -F | --fdir)	shift
      fastq_dir=$1
      ;;
    -o)	shift
      output_dir=$1
      ;;
    --output-dir=*)
      output_dir=${1/--output-dir=/}
      ;;
    -t)	shift
      threads=$1
      ;;
    --threads=*)
      threads=${1/--threads=/}
      ;;
    -h | --help)	shift
      usage
      echo ""
      echo ""
      echo ""
      echo "kallisto bus help."
      bash kallisto bus
      exit 0
      ;;
    *)
      extra_parameters+=("$1")
  esac
  shift
done

# Validating arguments.
if ! [[ -f "$samplesheet" ]]
then
  >&2 echo "Error: -S file parameter '$samplesheet' does not exists."
  usage
  exit 1
fi
if ! [[ -d "$fastq_dir" ]]
then
  >&2 echo "Error: -F directory parameter '$fastq_dir' does not exists."
  usage
  exit 1
fi

# Parse samples from samplesheet.
samples_raw=$(awk -F ',' '{print $1}' "$samplesheet")
read -r -a samples <<< "$samples_raw"

# Set FASTQ files.
fastq_files=()
for sample in "${samples[@]}"
do
  fastq_files+=("${fastq_dir}/${sample}_R1.fq.gz" "${fastq_dir}/${sample}_R2.fq.gz")
done

echo "Running kallisto bus"
kallisto bus \
  --output-dir="$output_dir" \
  --threads="$threads" \
  "${extra_parameters[@]}" \
  "${fastq_files[@]}"
