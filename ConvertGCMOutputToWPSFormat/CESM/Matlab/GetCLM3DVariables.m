function [nout] = GetCLM3DVariables(ncWPS,cam,itime,hdate,soil_depths)

% function [] = GetCLM3DVariables(ncWPS,cam,itime,hdate,soil_depths)
%
%   reads a couple of 2D variables from CLM climatology netcdf files 
%   and adds them to a specially-formatted netcdf file that
%   contains the information needed for these 
%   variables to be output in Intermediate format for WRF WPS.
%
%   The input, cam, is a structure holding useful information about
%   the setup of the run (e.g, Nlon, Nlat, etc.)

tt_climo = mod(double(ncread(cam.nc,'time',itime,1)),365); % day of year                                                          

clear tmp
tmp.levgrnd = double(ncread(cam.nc_clm_h0,'levgrnd'));    
Nlevgrnd = length(tmp.levgrnd);

time = double(ncread(cam.nc_clm_h0,'time'));

start = [1 1 1 1]; %  Only one time in the monthly-mean output
                   %  files from CLM and CICE
count = [cam.Nlon cam.Nlat Nlevgrnd 1];
wh = {'TSOI','H2OSOI','TSOI_ICE'};
for k = 1:length(wh)
  tmp.(wh{k}) = squeeze(interp1(time, ...
                                permute(double(ncread(cam.nc_clm_h0,wh{k})),[4 1 2 3]), ...
                                tt_climo,'linear')); %,start,count));
end

% interface depths for GCM soil levels
tmp.levgrndi = [0; ...
                sqrt(tmp.levgrnd(1:end-1).*tmp.levgrnd(2:end)); ...
                1.5*tmp.levgrnd(end) - 0.5*tmp.levgrnd(end-1)];


Ndepth = length(soil_depths)-1;

tmp.ST = zeros(cam.Nlon,cam.Nlat,Ndepth);
tmp.STICE = zeros(cam.Nlon,cam.Nlat,Ndepth);
tmp.SM = zeros(cam.Nlon,cam.Nlat,Ndepth);

for k = 1:Ndepth
  htop = soil_depths(k);
  hbot = soil_depths(k+1);

  tmp.wgt = zeros(size(tmp.levgrnd));
  for ilev = 1:Nlevgrnd
    tmp.wgt(ilev) = max( 0, ...
                         min( [tmp.levgrndi(ilev+1) - tmp.levgrndi(ilev); ...
                        hbot - tmp.levgrndi(ilev); ...
                        tmp.levgrndi(ilev+1) - htop] ) );
    tmp.ST(:,:,k)= tmp.ST(:,:,k) + tmp.wgt(ilev)*tmp.TSOI(:,:,ilev);
    tmp.STICE(:,:,k) = tmp.STICE(:,:,k) + tmp.wgt(ilev)*tmp.TSOI_ICE(:,:,ilev);
    tmp.SM(:,:,k)= tmp.SM(:,:,k) + tmp.wgt(ilev)*tmp.H2OSOI(:,:,ilev);
  end

  tmp.ST(:,:,k) = tmp.ST(:,:,k)./sum(tmp.wgt);
  tmp.STICE(:,:,k) = tmp.STICE(:,:,k)./sum(tmp.wgt);
  tmp.SM(:,:,k) = tmp.SM(:,:,k)./sum(tmp.wgt);

end

% fill in missing values in TSOI with TSOI_ICE
nanind = find(isnan(tmp.ST)); 
tmp.ST(nanind) = tmp.STICE(nanind);

%%% convert CLM soil moisture in m3/m3 to kg/m3 for WPS
%%tmp.SM = 1e3*tmp.SM;

% $$$ figure(1)
% $$$ for k = 1:Ndepth; subplot(2,2,k); pcolor(tmp.ST(:,:,k)); shading flat; ...
% $$$         colorbar; end
% $$$ 
% $$$ figure(3)
% $$$ for k = 1:Ndepth; subplot(2,2,k); pcolor(tmp.SM(:,:,k)); shading flat; ...
% $$$         colorbar; end


%            WPS name   WPS level
cam.wh2D = {{'ST',200100,'K','soil temperature'}, ... % soil temperature in K
            {'SM',200100,'m3/m3','soil moisture'}, ... % soil moisture in m3/m3
           };

%  Get a list of 2D fields from CAM to be output.
%  Some of these are easily translated for WPS.  Others will
%  require a bit of computation.

nout = 0;
for m = 1:length(cam.wh2D)
  for k = 1:Ndepth
    nout = nout + 1;

    WPSname = sprintf('%s%.3d%.3d ',cam.wh2D{m}{1}, ...
                      round(100*soil_depths(k:k+1)));
% $$$     disp(WPSname)
    xlvl = cam.wh2D{m}{2};

    units_txt = cam.wh2D{m}{3};
    desc_txt = sprintf('%s for the %.3d-%.3d cm depth layer', ...
                       cam.wh2D{m}{4},round(100*soil_depths(k:k+1)));

    value = tmp.(cam.wh2D{m}{1})(:,:,k);

    if ~isempty(find(isnan(value)))
      disp(sprintf('%d locations for %s are unfilled',length(find(isnan(value))),WPSname))
    end

    value(isnan(value)) = -1.e30;

    % set up this variable for the netcdf output
    clear vinfo

    vname = sprintf('%s%.6d',strtrim(WPSname),xlvl);
    vinfo.Filename = ncWPS;
    vinfo.Name = vname;
    vinfo.Datatype = 'double';
    vinfo.Dimensions(1).Name = 'lon';
    vinfo.Dimensions(1).Length = cam.Nlon;
    vinfo.Dimensions(2).Name = 'lat';
    vinfo.Dimensions(2).Length = cam.Nlat;

    % add attributes for this variable
    ii = 1;
    vinfo.Attributes(ii).Name = 'WPSname';
    vinfo.Attributes(ii).Value = WPSname;
    ii = ii + 1;
    vinfo.Attributes(ii).Name = 'xlvl';
    vinfo.Attributes(ii).Value = xlvl;
    ii = ii + 1;
    vinfo.Attributes(ii).Name = 'xfcst';
    vinfo.Attributes(ii).Value = 0;
    ii = ii + 1;
    vinfo.Attributes(ii).Name = 'hdate';
    vinfo.Attributes(ii).Value = hdate;
    ii = ii + 1;
    vinfo.Attributes(ii).Name = 'units';
    vinfo.Attributes(ii).Value = units_txt; %ncreadatt(cam.nc,CAMname,'units');
    ii = ii + 1;
    vinfo.Attributes(ii).Name = 'desc';
    vinfo.Attributes(ii).Value = desc_txt; %ncreadatt(cam.nc,CAMname,'long_name');
    ii = ii + 1;

    ncwriteschema(ncWPS,vinfo);

    % fill in the value for each variable.
    %   Note that each slab of output is a separate variable in the
    %   netcdf file, whether it comes from a 2D or 3D output in CESM.
    ncwrite(ncWPS,vname,value)
  end

end