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

% get 2D CICE variables
wh = {'aice','hs','hi'};
for m = 1:length(wh)
  % read climatology
  var_in = double(ncread(cam.nc_cice_h0,wh{m}));

  % permute to put time dimension first
  cice.(wh{m}) = permute(var_in, [3 1 2]);
end

