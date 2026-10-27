source /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh


MRB_TOP_DIR=/rcfs/projects/dunelb/chur558/containers/worker/duneec/v10_17_01
LOCALPROD=localProducts_larsoft_v10_12_02_e26_prof
source ${MRB_TOP_DIR}/${LOCALPROD}/setup

setup geant4 v4_11_4_0 -q e26:prof  # mine
setup dunesw v10_12_02d00 -q prof:e26

##setup duneana v10_12_02d00 -q debug:e26
##setup duneana v10_12_02d00 -q prof:e26
#cd /rcfs/projects/dunelb/chur558/containers/worker/duneec/v10_17_01

cd /rcfs/projects/dunelb/chur558/containers/worker/duneec/v10_17_01/build_slf7.x86_64

mrbsetenv
export FHICL_FILE_PATH=/rcfs/projects/dunelb/chur558/containers/worker/duneec/v10_17_01/bkgdrun/fcl-ec:$FHICL_FILE_PATH
export FW_SEARCH_PATH=/rcfs/projects/dunelb/chur558/containers/worker/duneec/v10_17_01/bkgdrun/gdml-ec:$FW_SEARCH_PATH

export LD_PRELOAD=/cvmfs/larsoft.opensciencegrid.org/products/gcc/v12_1_0/Linux64bit+3.10-2.17/lib64/libstdc++.so.6

### for runtime do below too.
mrbslp
export LD_PRELOAD="$LD_PRELOAD $(ls ${GEANT4_FQ_DIR}/lib64/libG4*.so 2>/dev/null | tr '\n' ' ')"

# This uses n-capture, etc data set, that already have in my G4v11.4+ area
export G4NEUTRONHPDATA="$GEANT4_DATA_DIR"/JEFF-4.0 # over-rides G4NDL471 for n captures, etc, but not JENDL_HE, Fission, Inelastic gammas. Embellishes istopes.
export G4PROTONHPDATA="/people/chur558/geant4/install/share/Geant4/data/G4NDL4.7.1"
export G4DEUTERONHPDATA="/people/chur558/geant4/install/share/Geant4/data/G4NDL4.7.1"
export G4TRITONHPDATA="/people/chur558/geant4/install/share/Geant4/data/G4NDL4.7.1"
export G4HE3HPDATA="/people/chur558/geant4/install/share/Geant4/data/G4NDL4.7.1"
export G4ALPHAHPDATA="/people/chur558/geant4/install/share/Geant4/data/G4NDL4.7.1"


#cd /rcfs/projects/dunelb/chur558/containers/worker/duneec/v10_17_01/bkgdrun/slurmneutron
