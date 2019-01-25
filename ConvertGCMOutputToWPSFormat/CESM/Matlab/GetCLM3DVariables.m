function [nout] = GetCLM3DVariables(ncWPS,cam,clm,itime,hdate,soil_depths)

% function [] = GetCLM3DVariables(ncWPS,cam,itime,hdate,soil_depths)
%
%   reads a couple of 2D variables from CLM climatology netcdf files 
%   and adds them to a specially-formatted netcdf file that
%   contains the information needed for these 
%   variables to be output in Intermediate format for WRF WPS.
%
%   The input, cam, is a structure holding useful information about
%   the setup of the run (e.g, Nlon, Nlat, etc.)
%
%   The input, clm, is a structure holding monthly climatologies of
%   CLM variables.

% # of WRF soil depths
Ndepth = length(soil_depths)-1;

target_time = mod(double(ncread(cam.nc,'time',itime,1)),365); % day of year                                                          
if ~isempty(strfind(cam.nc_clm_h0,'climo'))
  target_time = mod(target_time,365); % day of year                                                          
end

% figure out where this time lies in the climatology and compute
% interpolation weights, so that the value of a climatology at time tt_climo should be
%   w1*f(i1) + w2*f(i1+1);
i1 = max(find(clm.time<target_time));
if isempty(i1) 
  i1=1; i2 = 1; % target_time < min(clm.time), extrapolate
                % from initial value
  w1 = 1;
elseif target_time > max(clm.time)
  i2 = i1; % extrapolate from final value
  w1 = 1;
else        
  i2 = i1+1; 
  w1 = (clm.time(i1+1)-target_time)/diff(clm.time(i1:i2));
end
w2 = 1 - w1;
% $$$ tt_climo = mod(double(ncread(cam.nc,'time',itime,1)),365); % day of
% $$$                                                            % year                                   
% $$$ 
% $$$ % figure out where this time lies in the climatology and compute
% $$$ % interpolation weights, so that the value of a climatology at time tt_climo should be
% $$$ %   w1*f(i1) + w2*f(i1+1);
% $$$ i1 = max(find(clm.time<tt_climo));
% $$$ w1 = (clm.time(i1+1)-tt_climo)/diff(clm.time(i1:i1+1));
% $$$ w2 = 1 - w1;

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

    vv = (cam.wh2D{m}{1});
    value = squeeze(w1*clm.(vv)(i1,:,:,k) + w2*clm.(vv)(i1+1,:,:,k));

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
    vinfo.Dimensions(1).Length = length(cam.lonind);
    vinfo.Dimensions(2).Name = 'lat';
    vinfo.Dimensions(2).Length = length(cam.latind);

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
    if ~cam.quiet 
      disp(sprintf('Writing %s to %s',vname,ncWPS))
    end
    ncwrite(ncWPS,vname,value)
  end

end