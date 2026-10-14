#!/bin/bash
# Usage: LAR_Nevts="-n 10000" LAR_Nevts_fShell="-n 100" ./submit.sh [max_concurrent_tasks]
#   LAR_Nevts        event option for all fcls
#   LAR_Nevts_fShell event option for the fShellLog fcls (default: same as LAR_Nevts)
#   LAR_EXTRA_ARGS   any other lar options, applied to all jobs (optional)
#   e.g. ./submit.sh 50   -> at most 50 tasks running at once
#
# Re-run failed jobs:  RERUN=1 [LAR_Nevts=...] ./submit.sh [max_concurrent_tasks]
#   A job counts as failed if its TFileService output file (the fileName in the fcl)
#   is missing from OUTPUT_DIR (run/root_files). Only those fcls are resubmitted.
#   Aborts if duneec-neutrons jobs are still queued/running (override: FORCE=1).

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
ALL_FCLS=$(find "$FCL_DIR" -maxdepth 1 -name '*.fcl' | sort)
if [[ -z "$ALL_FCLS" ]]; then
    echo "No .fcl files found in $FCL_DIR"; exit 1
fi

if [[ -n "$RERUN" ]]; then
    if [[ -z "$FORCE" ]] && command -v squeue >/dev/null; then
        ACTIVE=$(squeue -u "$USER" -h -n duneec-neutrons -o %i 2>/dev/null | wc -l)
        (( ACTIVE == 0 )) || { echo "$ACTIVE duneec-neutrons job(s) still queued/running; wait or use FORCE=1"; exit 1; }
    fi
    # Keep only fcls whose TFileService output file is not in OUTPUT_DIR
    FCLS=""
    while read -r fcl; do
        hist=$(grep -v '^\s*#' "$fcl" | grep 'TFileService' | head -1 | sed 's/.*fileName:[[:space:]]*"\([^"]*\)".*/\1/')
        if [[ -z "$hist" ]]; then
            echo "WARNING: no TFileService fileName in $(basename "$fcl"); resubmitting it"
        elif [[ -e "$OUTPUT_DIR/$hist" ]]; then
            continue
        fi
        echo "Re-run: $(basename "$fcl")  (missing ${hist:-?})"
        FCLS+="$fcl"$'\n'
    done <<< "$ALL_FCLS"
    [[ -n "$FCLS" ]] || { echo "All output files present in $OUTPUT_DIR; nothing to re-run"; exit 0; }
else
    FCLS="$ALL_FCLS"$'\n'
fi
printf '%s' "$FCLS" > "$RUN_DIR/fcl_list.txt"
N=$(wc -l < "$RUN_DIR/fcl_list.txt")

# Snapshot the scripts used for this run
cp "$SLURM_DIR/job.sh" "$SLURM_DIR/run_in_container.sh" "$RUN_DIR/"
chmod +x "$RUN_DIR/run_in_container.sh"

echo "${RERUN:+Re-running }$N fcl files. Run dir: $RUN_DIR"
echo "Events: ${LAR_Nevts:-<lar default>}; fShellLog: ${LAR_Nevts_fShell:-<lar default>}"
echo "Root files will be collected in: $OUTPUT_DIR"

sbatch \
    --array=1-${N}%${MAX_CONCURRENT} \
    --chdir="$RUN_DIR" \
    --output="$RUN_DIR/logs/%x_%A_%a.out" \
    --error="$RUN_DIR/logs/%x_%A_%a.err" \
    --export=ALL,RUN_DIR="$RUN_DIR",OUTPUT_DIR="$OUTPUT_DIR",LAR_EXTRA_ARGS="${LAR_EXTRA_ARGS}",LAR_Nevts="${LAR_Nevts}",LAR_Nevts_fShell="${LAR_Nevts_fShell}" \
    "$RUN_DIR/job.sh"
