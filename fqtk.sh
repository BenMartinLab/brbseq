#!/bin/bash
#SBATCH --account=def-bmartin
#SBATCH --time=03:00:00
#SBATCH --cpus-per-task=24
#SBATCH --mem=24G
#SBATCH --output=fqtk-%A.out

# exit when any command fails
set -e

if [[ -n "$CC_CLUSTER" ]]
then
  module purge
  module load StdEnv/2023
  module load rust/1.95.0
  echo
fi

script_name=$(basename "${BASH_SOURCE[0]}")
script_path=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
if [[ "$script_name" == "slurm_script" ]] && [[ -n "$SLURM_JOB_ID" ]]
then
  slurm_command=$(scontrol show job "$SLURM_JOB_ID" | awk -F '=' '$0 ~ /Command=/ {print $2; exit}')
  script_name=$(basename "$slurm_command")
  script_path=$(dirname "$slurm_command")
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
run_mode="${extra_parameters[0]}"
extra_parameters=("${extra_parameters[@]:1}")

echo "Running fqtk $run_mode"
"${script_path}/fqtk/fqtk" "$run_mode" \
  --threads "$threads" \
  "${extra_parameters[@]}"
