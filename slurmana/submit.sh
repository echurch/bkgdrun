#!/bin/bash
# Usage: ./submit.sh TOPDIR [max_concurrent_tasks]
#   TOPDIR must contain fcl_list.txt (one fcl path per line) and root_files/
SLURMANA=$(cd "$(dirname "$0")" && pwd)
TOPDIR=$(cd "${1:?usage: submit.sh TOPDIR [max_concurrent]}" && pwd) || exit 1
MAX_CONCURRENT=${2:-100}
FCL_LIST="$TOPDIR/fcl_list.txt"
[[ -f "$FCL_LIST" ]] || { echo "Missing $FCL_LIST"; exit 1; }
N=$(grep -c . "$FCL_LIST")
(( N > 0 )) || { echo "$FCL_LIST is empty"; exit 1; }

# Single output directory for the json files (override: OUTPUT_DIR=/path ./submit.sh ...)
OUTPUT_DIR=${OUTPUT_DIR:-$SLURMANA/output}
mkdir -p "$SLURMANA/logs" "$SLURMANA/work" "$OUTPUT_DIR"

echo "Submitting $N tasks from $FCL_LIST; json output -> $OUTPUT_DIR"
sbatch \
    --array=1-${N}%${MAX_CONCURRENT} \
    --chdir="$SLURMANA" \
    --output="$SLURMANA/logs/%x_%A_%a.out" \
    --error="$SLURMANA/logs/%x_%A_%a.err" \
    --export=ALL,SLURMANA="$SLURMANA",TOPDIR="$TOPDIR",OUTPUT_DIR="$OUTPUT_DIR" \
    "$SLURMANA/job.sh"
