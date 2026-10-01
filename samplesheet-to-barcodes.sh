#!/bin/bash

# exit when any command fails
set -e

# Get script filename.
script_name=$(basename "${BASH_SOURCE[0]}")
if [[ "$script_name" == "slurm_script" ]] && [[ -n "$SLURM_JOB_ID" ]]
then
  slurm_command=$(scontrol show job "$SLURM_JOB_ID" | awk -F '=' '$0 ~ /Command=/ {print $2; exit}')
  script_name=$(basename "$slurm_command")
fi

# Default values of some arguments.
samplesheet=samplesheet.csv
output=barcodes.txt

# Usage function.
usage() {
  echo
  echo "Usage: $script_name [-s <samplesheet.csv>] [-o <barcodes.txt>] [-h]"
  echo "  -s, --samplesheet: Samplesheet file (default: samplesheet.csv)"
  echo "  -o, --output: Output file containing barcodes (default: barcodes.txt)"
  echo "  -h, --help: Show this help"
}

# Parsing arguments.
while [ "$1" != "" ]; do
  case $1 in
    -s | --samplesheet) shift
      samplesheet=$1
      ;;
    -o | --output) shift
      output=$1
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      >&2 echo "Error: invalid parameter '$1'."
      usage
      exit 1
      ;;
  esac
  shift
done

barcode_column=$(awk -F ',' \
    'NR == 1 {for (i = 1; i <= NF; i++) if ($i == "barcode") {print i; exit(0)}}' \
    "$samplesheet")
awk -F ',' -v barcode_column="$barcode_column" \
    'NR > 1 {print $barcode_column}' \
    "$samplesheet" \
    > "$output"
