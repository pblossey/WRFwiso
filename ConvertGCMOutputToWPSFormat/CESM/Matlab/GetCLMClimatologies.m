function [clm] = GetCLMClimatologies(cam,soil_depths)

% function [clm] = GetCLMClimatologies(cam,soil_depths)
%
%   reads a monthly climatologies from netcdf files and
%   saves them in a structure, so that they can be used
%   repeatedly to interpolate in time for frequent boundary
%   conditions for WRF simulations.  The soil moisture/temperature
%   are integrated over the layers of the WRF soil model 
%   so that they will be ready for input to WPS.
%
%   The input, cam, is a structure holding useful information about
%   the setup of the run (e.g, Nlon, Nlat, etc.)

clm.time = double(ncread(cam.nc_clm_h0,'time'));

% get 2D CLM variables
wh = {'SNOWLIQ','SNOWICE','SNOWDP'};
for m = 1:length(wh)
  % read climatology
  var_in = double(ncread(cam.nc_clm_h0,wh{m}));

  % permute to put time dimension first
  clm.(wh{m}) = permute(var_in, [3 1 2]);
end

% # of WRF soil depths
Ndepth = length(soil_depths)-1;

clear tmp

% read in climatology from file, and transpose to put time
% dimension first.
wh = {'TSOI','H2OSOI','TSOI_ICE'};
for k = 1:length(wh)
  tmp.(wh{k}) = permute(double(ncread(cam.nc_clm_h0,wh{k})),[4 1 2 3]);
end

Nt_climo = size(tmp.TSOI,1);

% define interface depths for GCM soil levels
tmp.levgrnd = double(ncread(cam.nc_clm_h0,'levgrnd')); % soil level centers
Nlevgrnd = length(tmp.levgrnd);

% GCM soil interface levels.
tmp.levgrndi = [0; ...
                sqrt(tmp.levgrnd(1:end-1).*tmp.levgrnd(2:end)); ...
                1.5*tmp.levgrnd(end) - 0.5*tmp.levgrnd(end-1)];

% Define arrays with soil temperature and moisture for WRF soil layers
clm.ST = zeros(Nt_climo,cam.Nlon,cam.Nlat,Ndepth);
clm.STICE = zeros(Nt_climo,cam.Nlon,cam.Nlat,Ndepth);
clm.SM = zeros(Nt_climo,cam.Nlon,cam.Nlat,Ndepth);

for k = 1:Ndepth
  htop = soil_depths(k);
  hbot = soil_depths(k+1);

  tmp.wgt = zeros(size(tmp.levgrnd));
  for ilev = 1:Nlevgrnd
    tmp.wgt(ilev) = max( 0, ...
                         min( [tmp.levgrndi(ilev+1) - tmp.levgrndi(ilev); ...
                        hbot - tmp.levgrndi(ilev); ...
                        tmp.levgrndi(ilev+1) - htop] ) );
    clm.ST(:,:,:,k)= clm.ST(:,:,:,k) + tmp.wgt(ilev)*tmp.TSOI(:,:,:,ilev);
    clm.STICE(:,:,:,k) = clm.STICE(:,:,:,k) + tmp.wgt(ilev)*tmp.TSOI_ICE(:,:,:,ilev);
    clm.SM(:,:,:,k)= clm.SM(:,:,:,k) + tmp.wgt(ilev)*tmp.H2OSOI(:,:,:,ilev);
  end

  clm.ST(:,:,:,k) = clm.ST(:,:,:,k)./sum(tmp.wgt);
  clm.STICE(:,:,:,k) = clm.STICE(:,:,:,k)./sum(tmp.wgt);
  clm.SM(:,:,:,k) = clm.SM(:,:,:,k)./sum(tmp.wgt);

end

% fill in missing values in TSOI with TSOI_ICE
nanind = find(isnan(clm.ST)); 
clm.ST(nanind) = clm.STICE(nanind);

% Now, we have saved the CLM soil moisture and soil temperature
%   climatologies on the WRF soil layer grid and can use these
%   to compute the soil moisture/temperature values at different times.
