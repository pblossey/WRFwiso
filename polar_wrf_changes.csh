#!/bin/csh

#bloss: Note that this is taken from README.PWRF.V3.9.1

# first make changes in WRF codebase
pushd WRFV3/

# store previous versions of files replaced by polar WRF
mv share/module_soil_pre.F share/module_soil_pre.F-unpolar
mv run/LANDUSE.TBL run/LANDUSE.TBL-unpolar
mv run/VEGPARM.TBL run/LANDUSE.TBL-unpolar
mv dyn_em/module_first_rk_step_part1.F dyn_em/module_first_rk_step_part1.F-unpolar
mv dyn_em/module_big_step_utilities_em.F dyn_em/module_big_step_utilities_em.F-unpolar
mv dyn_em/module_initialize_real.F dyn_em/module_initialize_real.F-unpolar
mv phys/module_sf_noahlsm.F phys/module_sf_noahlsm.F-unpolar
mv phys/module_sf_noahdrv.F phys/module_sf_noahdrv.F-unpolar
mv phys/module_surface_driver.F phys/module_surface_driver.F-unpolar
mv phys/module_sf_noahlsm_glacial_only.F phys/module_sf_noahlsm_glacial_only.F-unpolar
mv phys/module_sf_noah_seaice.F phys/module_sf_noah_seaice.F-unpolar
mv phys/module_sf_noah_seaice_drv.F phys/module_sf_noah_seaice_drv.F-unpolar
mv phys/module_mp_morr_two_moment.F phys/module_mp_morr_two_moment.F-unpolar

# link to polar WRF versions.
pushd share 
ln -s ../../PWRF3.9.1/share/module_soil_pre.F.PWRF3.9.1 module_soil_pre.F
popd

pushd run
ln -s ../../PWRF3.9.1/run/LANDUSE.TBL.PWRF3.9.1 LANDUSE.TBL
ln -s ../../PWRF3.9.1/run/VEGPARM.TBL.PWRF3.9.1 VEGPARM.TBL
popd

pushd phys
ln -s ../../PWRF3.9.1/phys/module_sf_noahlsm.F.PWRF3.9.1 module_sf_noahlsm.F
ln -s ../../PWRF3.9.1/phys/module_sf_noahdrv.F.PWRF3.9.1 module_sf_noahdrv.F
ln -s ../../PWRF3.9.1/phys/module_surface_driver.F.PWRF3.9.1 module_surface_driver.F
ln -s ../../PWRF3.9.1/phys/module_sf_noahlsm_glacial_only.F.PWRF3.9.1 module_sf_noahlsm_glacial_only.F
ln -s ../../PWRF3.9.1/phys/module_sf_noah_seaice.F.PWRF3.9.1 module_sf_noah_seaice.F
ln -s ../../PWRF3.9.1/phys/module_sf_noah_seaice_drv.F.PWRF3.9.1 module_sf_noah_seaice_drv.F
ln -s ../../PWRF3.9.1/phys/module_mp_morr_two_moment.F.PWRF3.9.1 module_mp_morr_two_moment.F
popd

pushd dyn_em
ln -s ../../PWRF3.9.1/dyn_em/module_first_rk_step_part1.F.PWRF3.9.1 module_first_rk_step_part1.F
ln -s ../../PWRF3.9.1/dyn_em/module_big_step_utilities_em.F.PWRF3.9.1 module_big_step_utilities_em.F
ln -s ../../PWRF3.9.1/dyn_em/module_initialize_real.F.PWRF3.9.1 module_initialize_real.F
popd

popd

# next, make changes in WPS to metgrid and geogrid tables.
pushd WPS/

pushd metgrid
mv METGRID.TBL.ARW METGRID.TBL.ARW-unpolar
ln -s ../../PWRF3.9.1/WPS/metgrid/METGRID.TBL.ARW
popd

pushd geogrid
mv GEOGRID.TBL.ARW GEOGRID.TBL.ARW-unpolar
ln -s ../../PWRF3.9.1/WPS/geogrid/GEOGRID.TBL.ARW
popd

popd

# output message about settings for fractional sea ice.

echo "********************"
echo "Advice from the polar WRF developers:"
echo " - if you wish to use FRACTIONAL SEA ICE, please set "
echo "             fractional_seaice=1 "
echo "   in the physics section of namelist input. This is a standard option in "
echo "   recent versions of WRF, however, it is not implemented unless you set the flag."
echo "   You should also set "
echo "             sst_update  = 1"
echo "   if you want sea surface temperature "
echo "   and sea ice specifications to update during a run. This is especially important"
echo "   during long runs. Lesheng Bai has included a fix into PWRF 3.6.1 so that the sea"
echo "   ice does update during a run if you direct it to do so."
