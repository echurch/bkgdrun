source /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh
## Seems to be no debug of dunesw
setup dunesw v10_12_02d00 -q prof:e26
#setup duneana v10_12_02d00 -q debug:e26
#setup duneana v10_12_02d00 -q prof:e26
cd /rcfs/projects/dunelb/chur558/containers/worker/duneec/v10_17_01
source localProducts_larsoft_v10_12_02_e26_prof/setup
cd /rcfs/projects/dunelb/chur558/containers/worker/duneec/v10_17_01/build_slf7.x86_64
mrbsetenv
export FHICL_FILE_PATH=/rcfs/projects/dunelb/chur558/containers/worker/duneec/v10_17_01/bkgdrun/fcl-ec:$FHICL_FILE_PATH
export FW_SEARCH_PATH=/rcfs/projects/dunelb/chur558/containers/worker/duneec/v10_17_01/bkgdrun/gdml-ec:$FW_SEARCH_PATH

mrbslp
cd /rcfs/projects/dunelb/chur558/containers/worker/duneec/v10_17_01/bkgdrun/slurm
