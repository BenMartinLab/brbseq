#!/bin/bash
#SBATCH --account=def-bmartin
#SBATCH --time=12:00:00
#SBATCH --cpus-per-task=48
#SBATCH --mem=120G
#SBATCH --output=star-%A.out

# exit when any command fails
set -e

if [[ -n "$CC_CLUSTER" ]]
then
  module purge
  module load StdEnv/2023
  module load star/2.7.11b
  echo
fi

# Default values of some arguments.
output_prefix=./alignment
output_dir_tmp=${SLURM_TMPDIR}
threads=${SLURM_CPUS_PER_TASK:-1}
bam_sorting_threads=${SLURM_CPUS_PER_TASK:-1}

# Parsing arguments.
while [ "$1" != "" ]; do
  case $1 in
    --outFileNamePrefix) shift
      output_prefix=$1
      ;;
    --outTmpDir) shift
      output_dir_tmp=$1
      ;;
    --runThreadN) shift
      threads=$1
      ;;
    --outBAMsortingThreadN) shift
      bam_sorting_threads=$1
      ;;
    *)
      extra_parameters+=("$1")
  esac
  shift
done

# Use outTmpDir parameter only if specified or if SLURM is used, otherwise use STAR default value.
if [[ -n "$output_dir_tmp" ]]
then
  output_dir_tmp_parameters=("--outTmpDir" "$output_dir_tmp")
fi

echo "Running STAR"
STAR \
  --outFileNamePrefix="$output_prefix" \
  "${output_dir_tmp_parameters[@]}" \
  --runThreadN "$threads" \
  --outBAMsortingThreadN "$bam_sorting_threads" \
  "${extra_parameters[@]}"
