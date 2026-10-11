#!/bin/bash
# Usage: LAR_Nevts="-n 10000" LAR_Nevts_fShell="-n 100" ./submit.sh [max_concurrent_tasks]
#   LAR_Nevts        event option for all fcls
#   LAR_Nevts_fShell event option for the fShellLog fcls (default: same as LAR_Nevts)
#   LAR_EXTRA_ARGS   any other lar options, applied to all jobs (optional)
#   e.g. ./submit.sh 50   -> at most 50 tasks running at once

FCL_DIR=/rcfs/projects/dunelb/chur558/containers/worker/duneec/v10_17_01/bkgdrun/fcl-neutrons
SLURM_DIR=$(cd "$(dirname "$0")" && pwd)
MAX_CONCURRENT=${1:-100}
LAR_Nevts_fShell=${LAR_Nevts_fShell-$LAR_Nevts}

# Single fixed run directory (reused/overwritten by each submission)
RUN_DIR="$SLURM_DIR/run"
# All output .root files from every task end up in one common directory
# (override with: OUTPUT_DIR=/some/path ./submit.sh)
OUTPUT_DIR=${OUTPUT_DIR:-$RUN_DIR/root_files}
mkdir -p "$RUN_DIR/logs" "$RUN_DIR/output" "$OUTPUT_DIR"

# Build the list of fcl files (sorted for reproducibility)
find "$FCL_DIR" -maxdepth 1 -name '*.fcl' | sort > "$RUN_DIR/fcl_list.txt"
N=$(wc -l < "$RUN_DIR/fcl_list.txt")

if (( N == 0 )); then
    echo "No .fcl files found in $FCL_DIR"; exit 1
fi

# Snapshot the scripts used for this run
cp "$SLURM_DIR/job.sh" "$SLURM_DIR/run_in_container.sh" "$RUN_DIR/"
chmod +x "$RUN_DIR/run_in_container.sh"

echo "Found $N fcl files. Run dir: $RUN_DIR"
echo "Events: ${LAR_Nevts:-<lar default>}; fShellLog: ${LAR_Nevts_fShell:-<lar default>}"
echo "Root files will be collected in: $OUTPUT_DIR"

sbatch \
    --array=1-${N}%${MAX_CONCURRENT} \
    --chdir="$RUN_DIR" \
    --output="$RUN_DIR/logs/%x_%A_%a.out" \
    --error="$RUN_DIR/logs/%x_%A_%a.err" \
    --export=ALL,RUN_DIR="$RUN_DIR",OUTPUT_DIR="$OUTPUT_DIR",LAR_EXTRA_ARGS="${LAR_EXTRA_ARGS}",LAR_Nevts="${LAR_Nevts}",LAR_Nevts_fShell="${LAR_Nevts_fShell}" \
    "$RUN_DIR/job.sh"
