#!/bin/bash
# Usage: ./submit.sh TOPDIR [max_concurrent_tasks]
#### Like: ./submit.sh ../slurm/run
#   TOPDIR defaults supply fcl_list.txt (one fcl path per line) and root_files/.
#   Override with FCL_LIST=/path/list.txt and/or ROOT_DIR=/path/to/root_files
SLURMANA=$(cd "$(dirname "$0")" && pwd)
TOPDIR=$(cd "${1:?usage: submit.sh TOPDIR [max_concurrent]}" && pwd) || exit 1
MAX_CONCURRENT=${2:-100}
BKGD=$(cd "$SLURMANA/.." && pwd)
FCL_LIST=${FCL_LIST:-$TOPDIR/fcl_list.txt}
ROOT_DIR=${ROOT_DIR:-$BKGD/slurm/run/root_files}
[[ -f "$FCL_LIST" ]] || { echo "Missing $FCL_LIST"; exit 1; }

# Only run fcls whose input root file already exists; skip the rest.
# The root file is the TFileService fileName in the fcl, up to "-hist" (j4bgexp appends "*-hist*.root").
# The filtered copy of the list is what the array tasks read.
mkdir -p "$SLURMANA/work"
RUN_LIST="$SLURMANA/work/fcl_list.$(date +%Y%m%d_%H%M%S).txt"
: > "$RUN_LIST"
while read -r fcl _; do
    [[ -n "$fcl" ]] || continue
    [[ "$fcl" = /* ]] || fcl="$TOPDIR/$fcl"
    hist=$(grep -v '^\s*#' "$fcl" 2>/dev/null | grep 'TFileService' | head -1 | sed 's/.*fileName:[[:space:]]*"\([^"]*\)".*/\1/')
    if [[ -n "$hist" ]] && compgen -G "$ROOT_DIR/${hist%%-hist*}*-hist*.root" >/dev/null; then
        echo "$fcl" >> "$RUN_LIST"
    else
        echo "Skipping $(basename "$fcl"): no root file matching $ROOT_DIR/${hist%%-hist*}*-hist*.root (TFileService: '${hist}')"
    fi
done < "$FCL_LIST"
FCL_LIST="$RUN_LIST"
N=$(grep -c . "$FCL_LIST")
(( N > 0 )) || { echo "No fcl has its root file yet; nothing to submit"; rm -f "$RUN_LIST"; exit 1; }

# Single output directory for the json files (override: OUTPUT_DIR=/path ./submit.sh ...)
OUTPUT_DIR=${OUTPUT_DIR:-$SLURMANA/output}
mkdir -p "$SLURMANA/logs" "$SLURMANA/work" "$OUTPUT_DIR"

echo "Submitting $N tasks from $FCL_LIST; json output -> $OUTPUT_DIR; root files <- $ROOT_DIR"
sbatch \
    --array=1-${N}%${MAX_CONCURRENT} \
    --chdir="$SLURMANA" \
    --output="$SLURMANA/logs/%x_%A_%a.out" \
    --error="$SLURMANA/logs/%x_%A_%a.err" \
    --export=ALL,SLURMANA="$SLURMANA",TOPDIR="$TOPDIR",FCL_LIST="$FCL_LIST",ROOT_DIR="$ROOT_DIR",OUTPUT_DIR="$OUTPUT_DIR" \
    "$SLURMANA/job.sh"
