#!/bin/bash
# Usage: run_in_container.sh <fcl_file> <task_work_dir>
# Executed INSIDE the container by job.sh

FCL="$1"
TASK_DIR="$2"

WORKER_DIR=/rcfs/projects/dunelb/chur558/containers/worker/duneec/v10_17_01/bkgdrun/slurmgamma

echo "=== Inside container on $(hostname) ==="
echo "FCL      : $FCL"
echo "TASK_DIR : $TASK_DIR"

# Same as your interactive step: source setup.sh after entering the container.
# (Adjust the path if setup.sh lives somewhere else.)
cd "$WORKER_DIR" || exit 1
source /rcfs/projects/dunelb/chur558/containers/worker//duneec/v10_17_01/bkgdrun/setup.sh 

# Make sure includes sitting next to the fcl are found
export FHICL_FILE_PATH="$(dirname "$FCL"):${FHICL_FILE_PATH}"

# Each task runs in its own directory so outputs (root files, hist files) don't collide
mkdir -p "$TASK_DIR"
cd "$TASK_DIR" || exit 1

echo "=== Starting lar at $(date) ==="
# Add -n <events>, -o <output>, etc. as needed via LAR_EXTRA_ARGS
NEV="$LAR_Nevts"
[[ "$(basename "$FCL")" == *fShellLog* ]] && NEV="${LAR_Nevts_fShell-$LAR_Nevts}"
ARGS="$NEV $LAR_EXTRA_ARGS"
echo "lar args: $ARGS"
lar -c "$FCL" ${ARGS}
STATUS=$?
echo "=== lar finished at $(date) with status $STATUS ==="

# Collect all .root outputs (hist files, art output) into the common directory.
# File names are unique per fcl (TFileService name encodes Volume/Material/Nuclide).
if [[ -n "$OUTPUT_DIR" ]]; then
    mkdir -p "$OUTPUT_DIR" || exit 1
    for f in *.root; do
        [[ -e "$f" ]] || continue
        mv "$f" "$OUTPUT_DIR/$f" || echo "WARNING: could not move $f"
    done
    echo "Root files moved to $OUTPUT_DIR"
else
    echo "WARNING: OUTPUT_DIR not set; root files left in $TASK_DIR"
fi
exit $STATUS
