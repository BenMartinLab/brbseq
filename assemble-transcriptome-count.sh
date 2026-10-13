#!/bin/bash
#SBATCH --account=def-bmartin
#SBATCH --time=3:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=20G
#SBATCH --output=assemble-transcriptome-count-%A.out

set -euo pipefail

###############################################################################
# Load modules on Alliance clusters
###############################################################################

if [[ -n "$CC_CLUSTER" ]]
then
  module purge
  module load StdEnv/2023
  module load r-bundle-bioconductor/3.21
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
script_dir="$(dirname "$script_path")"

Rscript "${script_dir}/assemble-transcriptome-count.R" "$@"
