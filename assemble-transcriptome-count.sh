#!/bin/bash
#SBATCH --account=def-bmartin
#SBATCH --time=3:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=20G
#SBATCH --output=assemble-transcriptome-count-%A.out

# exit when any command fails
set -e

if [[ -n "$CC_CLUSTER" ]]
then
  module purge
  module load StdEnv/2023
  module load r-bundle-bioconductor/3.21
  echo
fi

Rscript assemble-transcriptome-count.R "$@"
