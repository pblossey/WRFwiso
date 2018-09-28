#!/bin/bash

SYY=2007
SMM=5
SDD=26

EYY=2007
EMM=5
EDD=27

# load modules for intel/netcdf setup
source /etc/profile.d/modules.sh
module load intel/13.1.1 openmpi/1.6.4 netcdf/4.3.0

# clean up folder with WPS Intermediate format files from CESM
rm -f ConvertGCMOutputToWPSFormat/Output/*

# Run matlab script to pull data from CESM output and put it into a netcdf equivalent of the WPS intermediate format
pushd ConvertGCMOutputToWPSFormat/CESM/Matlab
matlab-r2017a -nodesktop -nosplash -nodisplay -r "CESM2WPSNetcdf('CESM','amip06a','amip06a.cam.h1.2007-05-26-00000.nc',${SYY},${SMM},${SDD},${EYY},${EMM},${EDD}); exit" &> log.matlab
popd

# compile the fortran program that converts this WPS-ready netcdf into binary WPS intermediate format
pushd ConvertGCMOutputToWPSFormat/Fortran
make clean; make all
popd

# convert the WPS-ready netcdf into binary WPS intermediate format
pushd ConvertGCMOutputToWPSFormat/Output
for file in `ls *.nc`; do nice ../Fortran/WPSNetcdf2IntermediateFormat ${file}; done
popd

# move into the WPS directory
pushd WPS/

# link to the CESM data in WPS Intermediate Format
rm -f CESM*
ln -sf ../ConvertGCMOutputToWPSFormat/Output/CESM* .

# set up netcdf library path for metgrid
# TODO: set up configure.wps and configure.wrf with -Wl,-rpath so that
#   we do not need to play these games with the LD_LIBRARY_PATH
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/local/modules/netcdf/4.3.0/intel/13.1.1/lib

# run metgrid
nice ./metgrid.exe &> log.metgrid 

# remove the netcdf path, so that nco will run properly
export LD_LIBRARY_PATH=/usr/local/intel/composer_xe_2013.3.163/compiler/lib/intel64

# recompute the sea ice, ice depth and snow-on-sea-ice amounts to
#   translate from the CESM world where land, ocean and sea ice share
#   grid cells to the WRF world where all ocean/sea ice grid cells are
#   free of land.  Also, CESM outputs for ice depth and
#   snow-on-sea-ice are weighted by ice area, so that compute the mean
#   values for locations with sea ice.
for file in `ls met_em*.nc`
   do 
    ncap2 -s "SEAICE=SIFRAC/(SIFRAC+OCNFRAC+1.e-12);ICEDEPTH=WGTSIDPTH/(SIFRAC+1.e-12);SNOWSI=WGTSNOWSI/(SIFRAC+1.e-12)" ${file} tmp.nc
     mv -f tmp.nc ${file}
done

popd

pushd WRFV3/test/em_real/

# set up netcdf library path for real.exe
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/local/modules/netcdf/4.3.0/intel/13.1.1/lib

nice ./real.exe &> log.real

popd
