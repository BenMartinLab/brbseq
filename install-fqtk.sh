#!/bin/bash

# exit when any command fails
set -e

if [[ -n "$CC_CLUSTER" ]]
then
  module purge
  module load StdEnv/2023
  module load rust/1.95.0
  echo
fi

script_path=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
mkdir -p "${script_path}/fqtk"
cd "${script_path}/fqtk"
git clone --branch v0.4.1 https://github.com/fulcrumgenomics/fqtk.git fqtk-src
cd fqtk-src
cargo build --release
cd ..
mv fqtk-src/target/release/* .
rm -rf fqtk-src
