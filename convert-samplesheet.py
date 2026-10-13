#!/usr/bin/env python3
import csv
import sys
import re
import argparse
from pathlib import Path

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

DNA_RE = re.compile(r"^[ACGT]+$", re.IGNORECASE)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def validate_required_columns(header: list[str]):
  """
  Validate that required columns are present in the samplesheet file.

  :param header: Column headers from samplesheet file.
  """
  required = {"barcode", "sample"}
  missing = required - set(header)
  if missing:
    sys.exit(f"ERROR: Missing required columns: {', '.join(missing)}")

def validate_barcode(barcode: str):
  """
  Validate that barcode is valid.

  :param barcode: barcode
  """
  if not DNA_RE.match(barcode):
    sys.exit(f"ERROR: Invalid barcode '{barcode}'. Must contain only ACGT.")

def detect_read_structure_columns(header: list[str]) -> list[str]:
  """
  Detect read structure columns that are used by `fqtk demux`.

  :param header: Column headers from samplesheet file.
  :return: Structure columns found in the samplesheet file.
  """
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


def read_samplesheet(samplesheet_path: Path) -> tuple[list[str], list[dict[str,str]]]:
  with samplesheet_path.open(encoding="utf-8-sig") as f:
    reader = csv.reader(f)
    header = next(reader)

    validate_required_columns(header)

    rows = []
    for row in reader:
      row_dict = dict(zip(header, row))
      row_dict = {k: v.strip() for k, v in row_dict.items()}
      validate_barcode(row_dict["barcode"])
      rows.append(row_dict)

  return header, rows


def write_whitelist(samplesheet_rows: list[dict[str,str]], whitelist_path: Path):
  """
  Writes barcode whitelist file for use with STAR.

  :param samplesheet_rows: Rows from samplesheet CSV file.
  :param whitelist_path: Where to write barcode whitelist file.
  """
  with open(whitelist_path, "w") as f:
    for row in samplesheet_rows:
      f.write(row["barcode"] + "\n")


def write_fqtk_metadata(samplesheet_headers: list[str], samplesheet_rows: list[dict[str,str]], fqtk_metadata_path: Path):
  """
  Writes metadata file for use with fqtk demux.

  :param samplesheet_headers: Headers from samplesheet file.
  :param samplesheet_rows: Rows from samplesheet CSV file.
  :param fqtk_metadata_path: Where to write fqtk metadata file.
  """
  read_struct_cols = detect_read_structure_columns(samplesheet_headers)

  metadata_header = ["sample_id", "barcode"] + read_struct_cols
  samplesheet_columns = list(metadata_header)
  samplesheet_columns.remove("sample_id")
  samplesheet_columns.insert(0, "sample")
  with open(fqtk_metadata_path, "w", newline="") as f:
    writer = csv.writer(f, delimiter="\t")
    writer.writerow(metadata_header)
    for row in samplesheet_rows:
      writer.writerow([row.get(col, "") for col in samplesheet_columns])


def write_frc(samplesheet_rows: list[dict[str,str]], frc_path: Path):
  """
  Writes barcode file for use with FastReadCounter.

  :param samplesheet_rows: Rows from samplesheet CSV file.
  :param frc_path: Where to write barcode file.
  """
  with open(frc_path, "w") as f:
    for row in samplesheet_rows:
      f.write(f"{row['barcode']}\t{row['sample']}\n")


def main():
  """
  Converts samplesheet to the following format:
    - STAR whitelist
    - `fqtk demux` metadata
    - FastReadCounter barcode file
  """
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
  frc = args.barcodes or samplesheet_path.with_suffix(".fastreadcounter.tsv")

  samplesheet_headers, samplesheet_rows = read_samplesheet(samplesheet_path)
  write_whitelist(samplesheet_rows, whitelist)
  write_fqtk_metadata(samplesheet_headers, samplesheet_rows, metadata)
  write_frc(samplesheet_rows, frc)

  print("Conversion complete.")
  print(f"STAR whitelist:        {whitelist}")
  print(f"fqtk metadata:         {metadata}")
  print(f"FastReadCounter file:  {frc}")


if __name__ == "__main__":
  main()
