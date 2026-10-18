#!/bin/bash
#SBATCH --job-name=duneec-neutrons
#SBATCH --account=dunelb            # check with: sacctmgr show assoc user=$USER
#SBATCH --partition=shared           # check with: sinfo  (e.g. slurm, short, ...)
#SBATCH --time=36:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
# --array, --output, --error, --chdir are supplied by submit.sh

echo "=== Job ${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID} on $(hostname) at $(date) ==="

# RUN_DIR is passed in by submit.sh
: "${RUN_DIR:?RUN_DIR not set}"
FCL_LIST="$RUN_DIR/fcl_list.txt"

# Select this task's fcl file (array indices are 1-based -> line number)
FCL=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$FCL_LIST")
if [[ -z "$FCL" ]]; then
    echo "No fcl file for task ${SLURM_ARRAY_TASK_ID}"; exit 1
fi
FCL_BASE=$(basename "$FCL" .fcl)
TASK_DIR="$RUN_DIR/output/${SLURM_ARRAY_TASK_ID}_${FCL_BASE}"

# ---- Host-side setup (same as interactive step 1) ----
source /people/chur558/setup_dune.sh
cd /rcfs/projects/dunelb/chur558/containers/worker/duneec/v10_17_01/bkgdrun/submit

# ---- Container: COPY THESE FROM setup_app.sh, using exec instead of shell ----
APPTAINER=/cvmfs/oasis.opensciencegrid.org/mis/apptainer/current/bin/apptainer
CONTAINER_IMAGE=/cvmfs/singularity.opensciencegrid.org/fermilab/fnal-dev-sl7:latest
BIND_OPTS="-B /cvmfs,/opt,/run/user,/etc/hostname,/etc/hosts,/etc/krb5.conf,/rcfs,/people"

# module load apptainer   # uncomment if setup_app.sh / setup_dune.sh does this
"$APPTAINER" exec $BIND_OPTS --ipc --pid "$CONTAINER_IMAGE" \
    /bin/bash "$RUN_DIR/run_in_container.sh" "$FCL" "$TASK_DIR"
STATUS=$?

echo "=== Task ${SLURM_ARRAY_TASK_ID} ($FCL_BASE) exit status $STATUS at $(date) ==="
exit $STATUS
