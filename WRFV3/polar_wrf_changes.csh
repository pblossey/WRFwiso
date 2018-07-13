#!/bin/csh

#bloss: Note that this is taken from README.PWRF.V3.9.1

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
ln -s ../PWRF3.9.1/share/module_soil_pre.F.PWRF3.9.1 share/module_soil_pre.F
ln -s ../PWRF3.9.1/run/LANDUSE.TBL.PWRF3.9.1 run/LANDUSE.TBL
ln -s ../PWRF3.9.1/run/VEGPARM.TBL.PWRF3.9.1 run/VEGPARM.TBL
ln -s ../PWRF3.9.1/phys/module_sf_noahlsm.F.PWRF3.9.1 phys/module_sf_noahlsm.F
ln -s ../PWRF3.9.1/phys/module_sf_noahdrv.F.PWRF3.9.1 phys/module_sf_noahdrv.F
ln -s ../PWRF3.9.1/phys/module_surface_driver.F.PWRF3.9.1 phys/module_surface_driver.F
ln -s ../PWRF3.9.1/phys/module_sf_noahlsm_glacial_only.F.PWRF3.9.1 phys/module_sf_noahlsm_glacial_only.F
ln -s ../PWRF3.9.1/phys/module_sf_noah_seaice.F.PWRF3.9.1 phys/module_sf_noah_seaice.F
ln -s ../PWRF3.9.1/phys/module_sf_noah_seaice_drv.F.PWRF3.9.1 phys/module_sf_noah_seaice_drv.F
ln -s ../PWRF3.9.1/phys/module_mp_morr_two_moment.F.PWRF3.9.1 phys/module_mp_morr_two_moment.F
ln -s ../PWRF3.9.1/dyn_em/module_first_rk_step_part1.F.PWRF3.9.1 dyn_em/module_first_rk_step_part1.F
ln -s ../PWRF3.9.1/dyn_em/module_big_step_utilities_em.F.PWRF3.9.1 dyn_em/module_big_step_utilities_em.F
ln -s ../PWRF3.9.1/dyn_em/module_initialize_real.F.PWRF3.9.1 dyn_em/module_initialize_real.F

echo "********************
> Advice from the polar WRF developers:
>  - if you wish to use FRACTIONAL SEA ICE, please set 
>              fractional_seaice=1 
>    in the physics section of namelist input. This is a standard option in 
>    recent versions of WRF, however, it isn't implemented unless you set the flag.
>    You should also set 
>              sst_update  = 1
>    if you want sea surface temperature 
>    and sea ice specifications to update during a run. This is especially important
>    during long runs. Lesheng Bai has included a fix into PWRF 3.6.1 so that the sea
>    ice does update during a run if you direct it to do so."