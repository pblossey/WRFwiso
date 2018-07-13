function [ncout] = CreateCESMFiniteVolumeNetcdfSchema(model,hdate,lon,lat);

  % create a netcdf file for all of the slabs
  ncout.Filename = sprintf('%s.nc',hdate);
  ncout.Name = '/';
  ncout.Dimensions(1).Name = 'lon';
  ncout.Dimensions(1).Length = length(lon);
  ncout.Dimensions(2).Name = 'lat';
  ncout.Dimensions(2).Length = length(lat);

  % save grid and model properties as global attributes in the
  % netcdf file.  These will be included in the WPS Intermediate Format.
  ii = 1;
  ncout.Attributes(ii).Name = 'datasource';
  ncout.Attributes(ii).Value = model;
  ii = ii + 1;

  ncout.Attributes(ii).Name = 'hdate';
  ncout.Attributes(ii).Value = hdate;
  ii = ii + 1;

  ncout.Attributes(ii).Name = 'ounit';
  ncout.Attributes(ii).Value = 12;
  ii = ii + 1;

  ncout.Attributes(ii).Name = 'version';
  ncout.Attributes(ii).Value = 5;
  ii = ii + 1;

  ncout.Attributes(ii).Name = 'nx';
  ncout.Attributes(ii).Value = length(lon);
  ii = ii + 1;

  ncout.Attributes(ii).Name = 'ny';
  ncout.Attributes(ii).Value = length(lat);
  ii = ii + 1;

  ncout.Attributes(ii).Name = 'map_source';
  ncout.Attributes(ii).Value = ...
      ['iCAM based on Nusbaumer et al (2017, JAMES)']';
  ii = ii + 1;

  % projuection type: iproj==0 --> cylindrical equidistant
  ncout.Attributes(ii).Name = 'iproj';
  ncout.Attributes(ii).Value = 0; 
  ii = ii + 1;

  % starting position for grid, lat/lon
  ncout.Attributes(ii).Name = 'startloc';
  ncout.Attributes(ii).Value = 'SWCORNER';
  ii = ii + 1;

  ncout.Attributes(ii).Name = 'startlat';
  ncout.Attributes(ii).Value = lat(1);
  ii = ii + 1;

  ncout.Attributes(ii).Name = 'startlon';
  ncout.Attributes(ii).Value = lon(1);
  ii = ii + 1;

  % grid spacing in degrees for latitude/longitude
  ncout.Attributes(ii).Name = 'deltalat';
  ncout.Attributes(ii).Value = lat(2)-lat(1);
  ii = ii + 1;

  ncout.Attributes(ii).Name = 'deltalon';
  ncout.Attributes(ii).Value = lon(2)-lon(1); 
  ii = ii + 1;

  % specify earth radius in km (from models/csm_share/shr/shr_const_mod.F90)
  ncout.Attributes(ii).Name = 'earth_radius';
  ncout.Attributes(ii).Value = 6371.22; 
  ii = ii + 1;

  ncout.Attributes(ii).Name = 'is_wind_grid_rel';
  ncout.Attributes(ii).Value = 0; 
  ii = ii + 1;

