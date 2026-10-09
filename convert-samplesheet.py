#!/usr/bin/env python3
import csv
import sys
import re
import argparse
from pathlib import Path

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

COLUMN_MAP = {
  "Name": "sample_id",
  "id": "sample_id",
  "sample_id": "sample_id",
  "Sample": "sample_name",
  "sample": "sample_name",
  "sample_name": "sample_name",
  "B1": "barcode",
  "barcode": "barcode",
}

DNA_RE = re.compile(r"^[ACGT]+$", re.IGNORECASE)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def normalize_header(header):
  return [COLUMN_MAP.get(col.strip(), col.strip()) for col in header]

def validate_required_columns(header):
  required = {"barcode", "sample_name"}
  missing = required - set(header)
  if missing:
    sys.exit(f"ERROR: Missing required columns: {', '.join(missing)}")

def validate_barcode(barcode):
  if not DNA_RE.match(barcode):
    sys.exit(f"ERROR: Invalid barcode '{barcode}'. Must contain only ACGT.")

def detect_read_structure_columns(header):
  rs_cols = []
  for col in header:
    if col.startswith("read_structure_"):
      suffix = col.replace("read_structure_", "")
      if suffix.isdigit():
        rs_cols.append(col)

  if rs_cols:
    nums = sorted(int(c.split("_")[2]) for c in rs_cols)
    expected = list(range(1, nums[-1] + 1))
    if nums != expected:
      sys.exit(
        f"ERROR: read_structure columns must be continuous from 1..{nums[-1]} "
        f"(found {nums})"
      )

  return sorted(rs_cols)

# ---------------------------------------------------------------------------
# Conversion
# ---------------------------------------------------------------------------

def convert_samplesheet(samplesheet_path, whitelist_path, metadata_path, frc_path):
  samplesheet_path = Path(samplesheet_path)

  with samplesheet_path.open(encoding="utf-8-sig") as f:
    reader = csv.reader(f)
    header = normalize_header(next(reader))

    validate_required_columns(header)
    read_struct_cols = detect_read_structure_columns(header)

    rows = []
    for row in reader:
      row_dict = dict(zip(header, row))
      row_dict = {k: v.strip() for k, v in row_dict.items()}
      validate_barcode(row_dict["barcode"])
      rows.append(row_dict)

  # STAR whitelist
  with open(whitelist_path, "w") as f:
    for row in rows:
      f.write(row["barcode"] + "\n")

  # fqtk metadata
  metadata_header = ["sample_id", "barcode"] + read_struct_cols
  extra_cols = [
    col for col in header
    if col not in metadata_header and col != "sample_name"
  ]
  metadata_header += extra_cols

  with open(metadata_path, "w", newline="") as f:
    writer = csv.writer(f, delimiter="\t")
    writer.writerow(metadata_header)
    for row in rows:
      writer.writerow([row.get(col, "") for col in metadata_header])

  # FastReadCounter barcode file
  with open(frc_path, "w") as f:
    for row in rows:
      f.write(f"{row['barcode']}\t{row['sample_name']}\n")

  print("Conversion complete.")
  print(f"STAR whitelist:        {whitelist_path}")
  print(f"fqtk metadata:         {metadata_path}")
  print(f"FastReadCounter file:  {frc_path}")

# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
  parser = argparse.ArgumentParser(
    description="Convert BRB-seq samplesheet into STAR whitelist, fqtk metadata, and FastReadCounter barcode file."
  )

  parser.add_argument(
    "samplesheet",
    nargs="?",
    help="Input samplesheet CSV file."
  )

  parser.add_argument(
    "-i", "--input",
    help="Input samplesheet CSV file (alternative to positional argument)."
  )

  parser.add_argument(
    "-w", "--whitelist",
    help="Output STAR whitelist file."
  )

  parser.add_argument(
    "-m", "--metadata",
    help="Output fqtk metadata CSV file."
  )

  parser.add_argument(
    "-b", "--barcodes",
    help="Output FastReadCounter barcode TSV file."
  )

  args = parser.parse_args()

  # Determine input file
  samplesheet = args.samplesheet or args.input
  if not samplesheet:
    sys.exit("ERROR: You must specify a samplesheet (positional or --input).")

  samplesheet_path = Path(samplesheet)
  if not samplesheet_path.exists():
    sys.exit(f"ERROR: Samplesheet '{samplesheet}' does not exist.")

  # Default output paths
  whitelist = args.whitelist or samplesheet_path.with_suffix(".whitelist.txt")
  metadata = args.metadata or samplesheet_path.with_suffix(".fqtk_metadata.tsv")
  barcodes = args.barcodes or samplesheet_path.with_suffix(".fastreadcounter.tsv")

  convert_samplesheet(samplesheet, whitelist, metadata, barcodes)


if __name__ == "__main__":
  main()
