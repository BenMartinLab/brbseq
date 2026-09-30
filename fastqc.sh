#!/bin/bash
#SBATCH --account=def-bmartin
#SBATCH --time=03:00:00
#SBATCH --cpus-per-task=24
#SBATCH --mem=24G
#SBATCH --output=fastqc-%A.out

# exit when any command fails
set -e

if [[ -n "$CC_CLUSTER" ]]
then
  module purge
  module load StdEnv/2023
  module load fastqc/0.12.1
  echo
fi

threads=${SLURM_CPUS_PER_TASK:-1}

# Parsing arguments.
while [ "$1" != "" ]; do
  case $1 in
    -t | --threads)	shift
      threads=$1
      ;;
    *)
      extra_parameters+=("$1")
  esac
  shift
done

echo "Running FastQC"
fastqc \
  --threads "$threads" \
  "${extra_parameters[@]}"
