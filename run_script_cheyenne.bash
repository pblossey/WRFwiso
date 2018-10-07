#!/bin/bash
#PBS -N AntarcWISO_real
#PBS -A UWAS0052
#PBS -l walltime=12:00:00
#PBS -q economy
#PBS -j oe
#PBS -m e
#PBS -M pblossey@uw.edu
#PBS -l select=1:ncpus=4:mpiprocs=1

SYY=2007
SMM=5
SDD=26

EYY=2007
EMM=6
EDD=24

### Set TMPDIR as recommended
export TMPDIR=/glade/scratch/$USER/temp
mkdir -p $TMPDIR

cd /glade/u/home/pblossey/scratch/WAIS/WRFwiso-2018-09-28/

# load modules for intel/netcdf setup
module load matlab nco

# clean up folder with WPS Intermediate format files from CESM
pushd ConvertGCMOutputToWPSFormat
if [ ! -d Output ]; then
  mkdir Output
else
  rm -f Output/*
fi
popd

# Run matlab script to pull data from CESM output and put it into a netcdf equivalent of the WPS intermediate format
pushd ConvertGCMOutputToWPSFormat/CESM/Matlab
echo " ***** Convert from CESM output to WPS-ready netcdf ***** "
matlab -nodesktop -nosplash -nodisplay -r "CESM2WPSNetcdf('CESM','amip06a','amip06a.cam.h1.2007-05-26-00000.nc',${SYY},${SMM},${SDD},${EYY},${EMM},${EDD}); exit" # &> log.matlab
popd

# compile the fortran program that converts this WPS-ready netcdf into binary WPS intermediate format
pushd ConvertGCMOutputToWPSFormat/Fortran
echo " ***** Making conversion program ***** "
make clean; make all
popd

# convert the WPS-ready netcdf into binary WPS intermediate format
pushd ConvertGCMOutputToWPSFormat/Output
echo " ***** Converting to Intermediate Format ***** "
for file in `ls *.nc`; do nice ../Fortran/WPSNetcdf2IntermediateFormat ${file}; done
popd

# move into the WPS directory
pushd WPS/

# link to the CESM data in WPS Intermediate Format
rm -f CESM*
ln -sf ../ConvertGCMOutputToWPSFormat/Output/CESM* .

# Use the Antarctica namelist
rm -f namelist.wps
cp -f namelist.wps.Antarctica.45km15km5km namelist.wps

# run metgrid
echo " ***** Running Metgrid ***** "
nice ./metgrid.exe # &> log.metgrid 

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
     ncatted -a FLAG_ICEDEPTH,global,c,i,1 -a FLAG_SNOWSI,global,c,i,1 ${file}
done

popd

pushd WRFV3/test/em_real/

# Use the Antarctica namelist
rm -f namelist.input
cp -f namelist.input.AntarcticaWISO.45km15km5km namelist.input

### Run the executable
mpiexec_mpt dplace -s 1 ./real.exe > log_real_2018-09-28

popd
