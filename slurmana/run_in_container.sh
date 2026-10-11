#!/bin/bash
# Usage: run_in_container.sh <fcl> <topdir> <output_dir> <work_dir>   (runs INSIDE the container)
FCL="$1"; TOPDIR="$2"; OUTPUT_DIR="$3"; WORK="$4"
WORKER_DIR=/rcfs/projects/dunelb/chur558/containers/worker
V=$WORKER_DIR/duneec/v10_17_01
SLURMANA=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
RADDIR=$V/gdml-ec/Radionuclides

[[ -f "$FCL" ]] || { echo "fcl not found: $FCL"; exit 1; }

# Values from the fcl (ignore commented lines)
BQ=$(grep -v '^\s*#' "$FCL" | grep -i 'BqPercc' | head -1 | sed 's/.*://; s/[][ ]//g; s/,.*//')
NUC=$(grep -v '^\s*#' "$FCL" | grep 'Nuclide:' | head -1 | sed 's/.*://; s/[]["[:space:]]//g; s/,.*//')
HIST=$(grep -v '^\s*#' "$FCL" | grep 'TFileService' | head -1 | sed 's/.*fileName:[[:space:]]*"\([^"]*\)".*/\1/')
SPEC="$RADDIR/$NUC.root"

# j4bgexp appends "*-hist*.root" to -i, so pass the name up to "-hist"
IN="$TOPDIR/root_files/${HIST%%-hist*}"

echo "FCL=$FCL"; echo "BqPercc=$BQ  Nuclide=$NUC"; echo "-i $IN  (hist file: $HIST)"; echo "-s $SPEC"
[[ -n "$BQ" && -n "$NUC" && -n "$HIST" ]] || { echo "Could not parse fcl"; exit 1; }
[[ -f "$SPEC" ]] || { echo "Spectrum file missing: $SPEC"; exit 1; }
ls $IN*-hist*.root >/dev/null 2>&1 || { echo "No input matches $IN*-hist*.root"; exit 1; }

cd "$WORKER_DIR" || exit 1
source "$WORKER_DIR/setup.sh"

# j4bgexp copies the fcl into $WORK/lar-tmp-out and runs lar there, so make sure
# includes next to the original fcl are still found
export FHICL_FILE_PATH="$(dirname "$FCL"):${FHICL_FILE_PATH}"

# j4bgexp finds its lar art-root output via os.getcwd()/lar-tmp-out/, so it must
# run from this absolute per-task directory
mkdir -p "$WORK" "$OUTPUT_DIR" && cd "$WORK" || exit 1
"$SLURMANA/j4bgexp.py" -f "$FCL" -c "$BQ" -i "$IN" -s "$SPEC"
STATUS=$?

if (( STATUS == 0 )); then
    mv -f ./*.json "$OUTPUT_DIR"/ && cd / && rm -rf "$WORK"
else
    echo "j4bgexp failed; scratch left in $WORK"
fi
exit $STATUS
