#!/usr/bin/env python3
# -*- coding: latin-1 -*-

import sys, getopt
import argparse
import pdb
import glob
from ROOT import PyConfig
PyConfig.IgnoreCommandLineOptions = True  # Else, passing in the "-h" flag causes crazyness.
import numpy as np
import collections
import subprocess
import os, datetime

from ROOT import TFile,TChain,TGraph

#from matplotlib import pyplot as plt

# globals
IntSpec = None
mass = None
frac = None
ipath = None
Volume = None
Material = None

import ROOT
import json
ROOT.gInterpreter.Declare(r'''
#include <string>
#include <algorithm>
#include <cctype>
#include "ROOT/RVec.hxx"

inline bool contains_ci(std::string s, const std::string &needle_lower) {
   // drop everything after the first NUL (fixed-size char[] branches)
   const auto z = s.find('\0');
   if (z != std::string::npos) s.resize(z);
   std::transform(s.begin(), s.end(), s.begin(),
                  [](unsigned char c){ return std::tolower(c); });
   return s.find(needle_lower) != std::string::npos;
}

inline bool contains_ci(const ROOT::VecOps::RVec<char> &v, const std::string &needle_lower) {
   return contains_ci(std::string(v.begin(), v.end()), needle_lower);
}
''')

def create_parser():
    parser = argparse.ArgumentParser(description="Making JSON is really annoying")
    parser.add_argument("-i", "--ifilepath", required=True, help="input file path")
    parser.add_argument("-c", "--conc", required=True, help="particle concentration in ppb")
    parser.add_argument("-f", "--fhicl", required=True, help="fhicl and maked the file")
#    parser.add_argument("-m", "--mass", default=10, help="mass of the volume")
    parser.add_argument("-s", "--spectrum", help="Production spectrum file")
    return parser.parse_args()

def runOne(fcl):

    import datetime, time
    
    date          = datetime.datetime.utcnow().strftime("%d-%B-%Y-%s")
    outdir        = os.getcwd() + "/lar-tmp-out/"
    txt_file      = 'oneshot_'  + date + ".out"
    art_root_file = 'oneshot_'  + date + '.root'

    if not os.path.exists(fcl):
        print(fcl + " does not exist")
        sys.exit(2)


   # Check if the RadioGen module has the material/volume, etc, we actually used for this dataset.
    if not os.path.exists(outdir):
        os.makedirs(outdir)

    dum = subprocess.Popen(('cp  ' + fcl + ' ' + outdir).split())
    dum.wait()
    fclnew   = fcl.split("/")[-1]
    fclnewcp = fclnew.split(".")[0]+"_cp.fcl"
    dum      = subprocess.Popen(('cp  ' + fcl + ' ' + outdir+fclnewcp).split())
    dum.wait()

    cmd_lar = 'cd ' + outdir
    cmd_lar += '; lar -c ' + fclnewcp + ' -n 1 -o ' + art_root_file
    cmd_lar += ' >& ' + txt_file
    cmd_lar += '; cd ' + os.getcwd()

    # Now edit the fclnewcp to turn on the art-root-file-writing line and ...
    # Check that the sam_metadata confirms that our art-root file goes with the ana-root files w our TTrees in them.
    file2 = open(outdir+fclnewcp,"r+")
    Volume = Nuclide = Material = "NA"

    with open(outdir+fclnewcp) as infile:
        for line in infile:
            if "Nuclide" in line and not "#" in line:
                Nuclide = line.split("\n")[0].replace("[","").replace("]","").replace("\"","").replace(" ","").split(":")[-1]
                if "," in Nuclide: # used an array of Nuclides for multiple boxes. Keep just first one.
                    Nuclide = Nuclide.split(",")[0]
            if "Material" in line and not "#" in line:
                Material = line.split("\n")[0].replace("[","").replace("]","").replace("\"","").replace(" ","").split(":")[-1]
                if "," in Material: # used an array of Materials for multiple boxes. Keep just first one.
                    Material = Material.split(",")[0]
            if "Volume" in line and not "#" in line:
                Volume = line.split("\n")[0].replace("[","").replace("]","").replace("\"","").replace(" ","").split(":")[-1]
                if "," in Volume: # used an array of Volumes for multiple boxes. Keep just first one.
                    Volume = Volume.split(",")[0]
            if "stream1" in line and "#" and "out1" in line:
                line = line.strip("#")
            if "end_paths" in line and not "stream1" in line:
                line = "#" + line
            if "end_paths" in line and "stream1" in line:
                line = line.strip("#")

            file2.write(line)

    file2.close()
    print ()
    print ("Nuclide/Material/Volume from OneEvent run is: " + Nuclide + "/" + Material +"/" + Volume + ". Check that these are what you used for simulation runs." )
    print ("Chkpoint, fcl file edited. Running lar now. Expect a ~6m wait.")


   # Popren(cd outdir; lar) to run one larsoft event and create the output
    p = subprocess.Popen(cmd_lar, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True) # last command needed for 2 commands, which requires to not do cmd.split()
    while p.poll() == None:
        print("sleeping 30 sec before checking in again for completion of our lar job ....")
        time.sleep(30)
    (results, errors) = p.communicate()

    if errors.decode() == '':
        pass
    else:
        print ('lar failed: ' + str(errors))
        exit(2)
    print ("Chkpoint, lar has run.")


    return_sam = subprocess.check_output(["sam_metadata_dumper",outdir+art_root_file], stderr=subprocess.STDOUT)  
    print ("Chkpoint, Called sam_metadata_dumper ")
    time.sleep(2)


   # go grab and parse out.txt and look for mass and use the art-root file for sam -- not the way it's done here till now.
    mass = 0
    with open(outdir+txt_file) as infile:
        for line in infile:
            if "Element" in line and "Weight" in line and Volume.lower().replace("vol","").replace("box","") in line.lower():

                mass =  float(line.split(" ")[-1].split("\n")[0])
                print("Adding mass for Volume " + Volume + ": " + str(mass) )
                break;
            elif "Element" in line and "Weight" in line and Material.lower() in line.lower() and "NA" in Volume: # This means I don't have a Volume name
                mass = float(line.split(" ")[-1].split("\n")[0])
                print("Adding mass for Material/Volume " + Material + "/" + line.split(" ")[1] + ": " + str(mass) )
                break;

    print ("Chkpoint, grep'd out the mass. It is " + str(mass) + " tonnes.")

 #   if  mass==0:
 #       print ("mass is 0. It's likely you don't have a properly set up larsoft envt. Ask Eric how to fix this... Or ...")
 #       print("Meanwhile, you may try to re-run, adding '-m mass_in_gms' to use for now rather than value faithfully used at simulation time.")
 #       exit(2) 

    return_conf = subprocess.check_output(["config_dumper",outdir+art_root_file], stderr=subprocess.STDOUT)  
    print ("Chkpoint, Called config_dumper " )
    time.sleep(2)

    return return_sam,return_conf,mass,Volume,Material

def dotfordash(d):
    new = {}
    for k, v in iter(d.items()):
        if isinstance(v, dict):
            v = dotfordash(v)
        new[k.replace('.', '-')] = v
    return new

def wrapwords(strin):
    
    rc = strin.split("\n\n")[1:-1]  # peel off header and trailer of config_dumper output.
    # Now go put double quotes around all the Keys, so Json/python knows they are keys, not some undefined variable.
    for line in range(len(rc)):
        wc = rc[line].split(" ")
        for word in range(len(wc)):
            loc = wc[word].find(":") 
            if loc != -1:
                wc[word] = wc[word].replace(':','"')
                wc[word] = '"' + wc[word] + ':'

        rc[line] = (" ").join(wc)
    strout = (" ").join(rc)

    # Now go fix sundry extra/missing line-returns, commas, etc from config_dumper
    strout = strout.replace("\n",",")
    strout = strout.replace("]","],")
    strout = strout.replace("}","},")
    strout = strout.replace("[,","[")
    strout = strout.replace("{,","{")
    strout = strout.replace(",,",",")
    # python needs Capital bools
    strout = strout.replace("false","False")
    strout = strout.replace("true","True")
    # mongodb complains about keys with "." in them.
    strout = strout.replace('.root":','-dot-root":')
    
    # The braces make it look, finally, like a dictionary.
    strout = "{" + strout + "}"

    return strout



def main(argv):
    import json
    
    try:
        opts, args = getopt.getopt(argv,"hi:c:f:s",["ifilepath=","conc=","frac[ppb]=","ispec[1/sec/ppb/gm]="])
    except getopt.GetoptError:
        print ('j4bgexp.py -i <ifilepath-wildcarded-in-quotes> -c <ppb> -f <fcl> [-s <int_persec_perppb_pergm>] [-m <mass_volume_gm>]')
        sys.exit(2)

#    cnt = 0
#    for opt, arg in opts:
#        if opt in ("-h","--help"):
#            print ('j4bgexp.py -i <ifilepath-wildcarded-in-quotes>  -c <ppb> -f <fhicl-file> [-s <spec-tgraph>]')
#            print ('e.g.: python j4bgexp.py  -i "/people/muns597/dune/run/Layer1_Th232/cneut_CryoLayer1_Th232_rn2    00cmv3_*/" -f "/path/to/fcl_used_to_make_sample.fcl" -c 235 ')
#            sys.exit()
#        elif opt in ("-i", "--ipath"):
#            ipath = str(arg)
#            cnt+=1
#        elif opt in ("-f", "--fhiclfile"):
#            fhiclfile = str(arg)
#            cnt+=1
#        elif opt in ("-c", "--conc"):
#            frac = float(arg)
#            cnt+=1
#        elif opt in ("-s", "--tgraph"):
#            IntSpec = str(arg)
#            cnt+=1
#        elif opt in ("-m", "--mass"):
 #           mass = float(arg)
 #           cnt+=1

#    if cnt<3 or cnt>5:
#        print ('j4bgexp.py needs at least -i, -c, -f flags with values.')
#        sys.exit()

    os.system("clear")

    args      = create_parser()
    ipath     = str  (args.ifilepath)
    fhiclfile = str  (args.fhicl    )
    frac      = float(args.conc     )
    IntSpec   = str  (args.spectrum )
#    mass      = float(args.mass     )

#    return_sam,return_conf,mass2,Volume,Material,Nuclide = runOne(fhiclfile)
    return_sam,return_conf,mass2,Volume,Material = runOne(fhiclfile)

    print("ipath1 = %s" % ipath)

    ipath += "*-hist*.root"
 
    print("ipath1 = %s" % ipath)

    print("filelist = %s" % glob.glob(ipath))

    filelist = glob.glob(ipath)


#    ifile = TFile(ipath)

#    ch2 = ifile.Get('largana/MCTTree') #TChain("largana/MCTTree")
    ch2 = TChain("largana/MCTTree")
#    if  not filelist or not len(filelist):
#        print("The-root file(s) we need from which to grab TTree does not exist. Please fix this problem.")
#        exit 
#
    for fn in filelist:
        tfn = TFile(fn)
        Nent = tfn.largana.Get("MCTTree").GetEntries()
        print("Entries in " + fn + ": " + str(Nent) )
        ch2.AddFile(fn)


    Ntot = ch2.GetEntries()
    print ("Total entries: " + str(Ntot))
    Ngood = 0
    Ncaps = 0
    Nspectrum = np.array([])

    NcapsInd = 0

    Nspectrum = np.array([])
    NspectrumInd = np.array([])
    parentCntDict = {}
    parentEnDict = {}

    ent2 = 0
    ent = 0
    fidvol = np.array([[-620.0,620.0],[-620.0,620.0],[50.0,6000.0]]) ## 6000.0
#    fidvol = np.array([[-550.0,550.0],[-550.0,550.0],[60.0,5950.0]]) ## 6000.0
    locCap = []
    evt = 12E12

    df = ROOT.RDataFrame(ch2)
#    ROOT.RDF.Experimental.AddProgressBar(df)   # replaces the manual "On entry ..." printout

    # ---- fiducial volume cut string -------------------------------------------
    fid = ("abs(MCOrigin[0]) < {xmax} && "
           "abs(MCOrigin[1]) < {ymax} && "
           "MCOrigin[2] > {zmin} && MCOrigin[2] < {zmax}").format(
               xmax=fidvol[0][1], ymax=fidvol[1][1],
               zmin=fidvol[2][0], zmax=fidvol[2][1])

    # ---- primary neutrons -----------------------------------------------------
    d_good = df.Filter('MCPdg == 2112 && contains_ci(MCProcess, "primary")', "primary n")

    # ---- capture gammas in LAr, inside fiducial volume ------------------------
    d_caps = (df.Filter('MCPdg == 22 && contains_ci(MCProcess, "ncapture") '
                        '&& contains_ci(MCMaterial, "lar")', "ncapture gamma in LAr")
              .Filter(fid, "fiducial")
              .Define("capX", "MCOrigin[0]")
              .Define("capY", "MCOrigin[1]")
              .Define("capZ", "MCOrigin[2]")
              .Define("capE", "MCMomentum[3]*1000."))   # MeV
    
    # ---- book everything, then run the event loop ONCE -----------------------
    nGood = d_good.Count()
    nCaps = d_caps.Count()
    cols  = d_caps.AsNumpy(["capX", "capY", "capZ", "capE", "MCParentID", "MCEvt"])

    Ngood = nGood.GetValue()
    Ncaps = nCaps.GetValue()

    locCap = list(zip(cols["capX"], cols["capY"], cols["capZ"]))

    # ---- per-(event, parent) energy sums  ==  the old parentEnDict flush ------
    keys = np.stack([cols["MCEvt"].astype(np.int64),
                     cols["MCParentID"].astype(np.int64)], axis=1)

    if len(keys):
        uniq, inv = np.unique(keys, axis=0, return_inverse=True)
        NspectrumInd = np.bincount(inv, weights=cols["capE"])        # MeV, one entry per parent neutron
        parentCnt    = np.bincount(inv)                              # gammas per parent (old parentCntDict)
    else:
        NspectrumInd = np.array([])
        parentCnt    = np.array([])

    NcapsInd = len(NspectrumInd)

    print("Ngood   =", Ngood)
    print("Ncaps   =", Ncaps)
    print("NcapsInd=", NcapsInd)
    df.Report().Print()      # nice cut-flow summary for free


    bins = np.arange(0.,10.10,0.10)   # MeV
    h,b = np.histogram(NspectrumInd,bins=bins)


    binsloc =  np.array([np.arange(fidvol[0][0],fidvol[0][1]+30.,30.), np.arange(fidvol[1][0],fidvol[1][1]+30.,30.), np.arange(fidvol[2][0],fidvol[2][1]+300,300.)],dtype=object)
    hloc,bloc = np.histogramdd(np.array(locCap).astype('float'),bins=binsloc)

    mydict = collections.OrderedDict()
    mydict["timestamp_utc"] = datetime.datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')
    mydict["host"] = os.uname()

    mydict["nentries"] = Ntot
    mydict["nprimaries"] = Ngood
    mydict["fiducialVolume"] = {"fidx":fidvol[0].tolist(),"fidy":fidvol[1].tolist(),"fidz":fidvol[2].tolist()}

    print ("At the shoving return_sam into dict stage")

    # eval() will turn our sam json-understood text into a dictionary.
    try:
        # Sometimes this fails due apparently to a warning bolted on by sam_metadata_dumper about SIM-IDEs
        print (f"return_sam for meta data: {return_sam} ")
        mydict["sam_metadata"] = json.loads(return_sam)

    except:
        try:
            mydict["sam_metadata"] = json.loads(str(return_sam).replace("\\n","").replace("\'","").split("available")[1])
        except:
            mydict["sam_metadata"] = "NULL"

    # mongodb complains about keys with "." in them.
    # Must now wrap all words in the config_metadata that hold a ":" with double quotes. Other formatting too. Only then can it be dicted.

    return_conf_fmt = wrapwords(return_conf.decode())

    mydict["config_metadata"] = return_conf_fmt

    # Let's go grab up the neutron decay info
    # look in 0th file path for gdml directory which should hold our sub-directory w root file with the TGraph that was used.
    try:
        f = TFile(IntSpec)
        IntSpec = f.Neutrons.Integral() * 10. # All these TGraphs require this *10.
        print ("Integrated spectrum is discovered and over-ridden: " + str(IntSpec) + " [1/ppb/sec/gm]")
    except:
        print ("TGraph spectrum used at sim time could not be found. ")
        print("You may try to re-run, adding '-s /path/to/ROOTFile-with-TGraph.root' to point to the spectrum used at simulation time.")
        pass

#    return_sam = return_sam.decode()
#    return_sam = return_sam.replace('.root":','-dot-root":')
#    return_sam = return_sam.replace('art.','art-')
#    return_sam = return_sam.replace('application.','application-')

    mydict["sam_metadata"] = dotfordash(mydict["sam_metadata"])

    print ("Integrated spectrum is: " + str(IntSpec) + " [1/ppb/sec/gm]")
    print ("mass is: " + str(mass2) + " [tonne]")
    print ("frac is: " + str(frac) + " [ppb]")

    print("Ngood: " + str(Ngood))
    tsim = Ngood/mass2/1.E6/frac/IntSpec # 1E6 to convert to gms
    tcapinv = NcapsInd/tsim ## was NcapsInd

    print ("tsim is thus: " + str(tsim) + " [sec]")
    print ("n capture rate is: " + str(tcapinv) + " [1/sec]")

    mydict["simfilepath0"] =  filelist[0]
    mydict["ncaptures"] = NcapsInd ## was NcapsInd
    mydict["hits"] = (h.tolist(),np.around(b,6).tolist())

    tmp = bloc
    for ii in range(len(bloc)):
        tmp[ii] = bloc[ii].tolist()
    mydict["location"] = (hloc.tolist(),tmp)
    mydict["primary"] = "neutrons"


    mydict["massMaterial_gm"] = mass2*1.0E6
    mydict["IntegratedSpectrum_invgm_ppb_sec"] = IntSpec 
    mydict["frac_ppb"] = frac
    mydict["simtime_sec"] = tsim
    mydict["ncaptime_invsec"] = tcapinv

### Finally, put a couple variables (redundantly) at top level, 26-Apr-2022.
    mydict["volume"] = Volume
    mydict["nuclide"] = "Null"
    mydict["material"] = Material
    print("mydict[]config_meta][cneutronGen]: ", mydict['config_metadata']['cNeutronGen'])
    cngkeys = str( mydict["config_metadata"]["cNeutronGen"].keys())
    print ("config_metadata.cneutronGen keys are " + cngkeys )
    if "Volume" in cngkeys:
        mydict["volume"] = mydict["config_metadata"]["cNeutronGen"]["Volume"][0] 

    if "Nuclide" in cngkeys:
        tmpnuc = mydict["config_metadata"]["cNeutronGen"]["Nuclide"][0] 
        ## re-order the string, per Sagar
        tmpnucbits = tmpnuc.split("_")
        radn = earlylate = total = leftover = ""
        for bit in tmpnucbits:
            if "Th" == bit or "U" == bit:
                radn = bit + "_"
            elif "early" in bit.lower() or "late" in bit.lower():
                earlylate = bit + "_"
            elif "total" in bit.lower():
                total = bit + "_"
            else:
                leftover += (bit + "_")
        tmpnuc2 = radn + earlylate + total #+ leftover 
        mydict["nuclide"] = tmpnuc2[:-1]  # drop final "_"
        if mydict["nuclide"] == '':
            mydict["nuclide"] = tmpnuc

        if "Th" in tmpnuc:
            mydict["nuclide"] = "Th232"
        elif "early" in tmpnuc.lower():
            mydict["nuclide"] = "U238"
        elif "late" in tmpnuc.lower():
            mydict["nuclide"] = "Ra226"

    ### Now go write the json file.
    prefix = 'bgdexp'
    sample = Volume+"-"+Material  # 'coldCryoLayer1-neutrons'
    import json
    fjout = prefix+'_'+sample+'_'+ mydict["nuclide"] +'.json'
    with open(fjout, 'w') as fp:
        json.dump(mydict, fp)

    print ("Created file " + fjout + ".")

if __name__ == "__main__":

 #   print ('Number of arguments:', len(sys.argv), 'arguments.')
 #   print ('Argument List:', str(sys.argv))

    main(sys.argv[1:])
