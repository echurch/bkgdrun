#!/bin/bash
#SBATCH --job-name=j4bgexp
#SBATCH --account=dunelb
#SBATCH --partition=slurm
#SBATCH --time=04:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
# --array, --output, --error, --chdir are supplied by submit.sh

echo "=== Job ${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID} on $(hostname) at $(date) ==="
: "${SLURMANA:?not set}" "${TOPDIR:?not set}" "${FCL_LIST:?not set}" "${ROOT_DIR:?not set}" "${OUTPUT_DIR:?not set}"

FCL=$(grep . "$FCL_LIST" | sed -n "${SLURM_ARRAY_TASK_ID}p" | awk '{print $1}')
[[ -n "$FCL" ]] || { echo "No fcl for task ${SLURM_ARRAY_TASK_ID}"; exit 1; }
[[ "$FCL" = /* ]] || FCL="$TOPDIR/$FCL"

source /people/chur558/setup_dune.sh
cd /rcfs/projects/dunelb/chur558/containers/worker

APPTAINER=/cvmfs/oasis.opensciencegrid.org/mis/apptainer/current/bin/apptainer
CONTAINER_IMAGE=/cvmfs/singularity.opensciencegrid.org/fermilab/fnal-dev-sl7:latest
BIND_OPTS="-B /cvmfs,/opt,/run/user,/etc/hostname,/etc/hosts,/etc/krb5.conf,/rcfs,/people"

"$APPTAINER" exec $BIND_OPTS --ipc --pid "$CONTAINER_IMAGE" \
    /bin/bash "$SLURMANA/run_in_container.sh" "$FCL" "$ROOT_DIR" "$OUTPUT_DIR" "$SLURMANA/work/${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}"
STATUS=$?
echo "=== Task ${SLURM_ARRAY_TASK_ID} exit status $STATUS at $(date) ==="
exit $STATUS
