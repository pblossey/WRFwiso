#!/bin/csh

echo Setting up seabreeze2d_x case by linking data files into this directory

echo linking to LANDUSE.TBL in ../../run directory

ln -sf ../../run/LANDUSE.TBL .
ln -sf ../../run/SOILPARM.TBL . # Noah Land Surface scheme
ln -sf ../../run/VEGPARM.TBL . # Noah Land Surface scheme
ln -sf ../../run/GENPARM.TBL . # Noah Land Surface scheme
ln -sf ../../run/RRTM_DATA_DBL RRTM_DATA # Double precision RRTM lookup table
ln -sf ../../run/wind-turbine-1.tbl .

echo done
