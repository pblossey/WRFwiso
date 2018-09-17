function [nout] = GetCICE2DVariables(ncWPS,cam,cice,itime,hdate)

% function [] = GetCLM2DVariables(ncWPS,cam,cice,itime,hdate)
%
%   reads a couple of 2D variables from CLM climatology netcdf files 
%   and adds them to a specially-formatted netcdf file that
%   contains the information needed for these 
%   variables to be output in Intermediate format for WRF WPS.
%
%   The input, cam, is a structure holding useful information about
%   the setup of the run (e.g, Nlon, Nlat, etc.)
%
%   The input, cice, is a structure holding monthly climatologies of 
%   CICE outputs

tt_climo = mod(double(ncread(cam.nc,'time',itime,1)),365); % day of year                                                          
% figure out where this time lies in the climatology and compute
% interpolation weights, so that the value of a climatology at time tt_climo should be
%   w1*f(i1) + w2*f(i1+1);
i1 = max(find(cice.time<tt_climo));
w1 = (cice.time(i1+1)-tt_climo)/diff(cice.time(i1:i1+1));
w2 = 1 - w1;


  %  Get a list of 2D fields from CAM to be output.
  %  Some of these are easily translated for WPS.  Others will
  %  require a bit of computation.
  
  %            CAM name    WPS name     WPS level
  cam.wh2D = {{'aice','SIFRAC   ',200100}, ... % sea ice fraction
              {'hs'  ,'WGTSNOWSI',200100}, ... % Snow depth on sea ice
              {'hi'  ,'WGTSIDPTH',200100}, ... % Sea ice depth
              };

  nout = 0;
  for m = 1:length(cam.wh2D)
    nout = nout + 1;

    CAMname = cam.wh2D{m}{1};
    WPSname = cam.wh2D{m}{2};
    xlvl = cam.wh2D{m}{3};

    % interpolate the climatology to the current time
    value = squeeze(w1*cice.(CAMname)(i1,:,:) + w2*cice.(CAMname)(i1+1,:,:));

    switch CAMname
      case {'hs'}
       units_txt = 'm';
       desc_txt = 'Snow depth on top of sea ice';
      case {'hi'}
       units_txt = 'm';
       desc_txt = 'Sea ice depth';
      case {'aice'}
       units_txt = '';
       desc_txt = 'Sea ice fraction';

       % convert from percent to fraction!!
       value = value/100;
    end

    if ~isempty(find(isnan(value)))
      disp(sprintf('%d locations for %s are unfilled',length(find(isnan(value))),CAMname))
    end

    % set missing values to zero -- seems reasonable for ice/snow thickness
    value(isnan(value)) = 0;

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

    vinfo.Attributes(ii).Name = 'missing_value';
    vinfo.Attributes(ii).Value = -1.e30; %ncreadatt(cam.nc,CAMname,'long_name');
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

