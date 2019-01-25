function [cice] = GetCICEClimatologies(cam)

% function [cice] = GetCICEClimatologies(cam)
%
%   reads a monthly climatologies from netcdf files and
%   saves them in a structure, so that they can be used
%   repeatedly to interpolate in time for frequent boundary
%   conditions for WRF simulations.  
%
%   The input, cam, is a structure holding useful information about
%   the setup of the run (e.g, Nlon, Nlat, etc.)

cice.time = double(ncread(cam.nc_cice_h0,'time'));

% use lat/lon indices from CAM.  These should coincide with those
% for sea ice.
Nlat_requested = length(cam.latind);
Nlon_requested = length(cam.lonind);

start = [cam.lonind(1) cam.latind(1) 1];
count = [Nlon_requested Nlat_requested length(cice.time)];

% get 2D CICE variables
wh = {'aice','hs','hi'};
for m = 1:length(wh)
  % read climatology
  var_in = double(ncread(cam.nc_cice_h0,wh{m},start,count));

  % permute to put time dimension first
  cice.(wh{m}) = permute(var_in, [3 1 2]);
end

