function [nout] = GetCLM2DVariables(ncWPS,cam,itime,hdate)

% function [] = GetCLM2DVariables(ncWPS,cam,itime,hdate)
%
%   reads a couple of 2D variables from CLM climatology netcdf files 
%   and adds them to a specially-formatted netcdf file that
%   contains the information needed for these 
%   variables to be output in Intermediate format for WRF WPS.
%
%   The input, cam, is a structure holding useful information about
%   the setup of the run (e.g, Nlon, Nlat, etc.)


  %  Get a list of 2D fields from CAM to be output.
  %  Some of these are easily translated for WPS.  Others will
  %  require a bit of computation.
  
  %            CAM name    WPS name     WPS level
  cam.wh2D = {{'SNOWLIQ','SNOW     ',200100}, ... % SWE in kg/m2
              {'SNOWDP', 'SNOWH    ',200100}, ... % snow depth in m
              };

  nout = 0;
  for m = 1:length(cam.wh2D)
    nout = nout + 1;

    CAMname = cam.wh2D{m}{1};
    WPSname = cam.wh2D{m}{2};
    xlvl = cam.wh2D{m}{3};

    start = [1 1 1]; %  Only one time in the monthly-mean output
                     %  files from CLM and CICE
    count = [cam.Nlon cam.Nlat 1];
    var_in = double(ncread(cam.nc_clm_h0,CAMname,start,count));

    switch CAMname
      case {'SNOWLIQ'}
       % combine SNOWLIQ and SNOWICE to give total snow water
       % equivalent in kg/m2
       value = double(ncread(cam.nc_clm_h0,'SNOWLIQ',start,count)) ...
               + double(ncread(cam.nc_clm_h0,'SNOWICE',start,count));

       units_txt = 'kg/m2';
       desc_txt = 'Snow water equivalent';
       
      case {'SNOWDP'}
       % WPS's SNOWH == CAM's SNOWDP, with both in meters
       value = var_in;

       units_txt = 'm';
       desc_txt = 'Snow depth';
    end

    if ~isempty(find(isnan(value)))
      disp(sprintf('%d locations for %s are unfilled',length(find(isnan(value))),CAMname))
    end

    % set missing values to zero -- seems reasonable for SWE and
    % snow depth...
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

    ncwriteschema(ncWPS,vinfo);

    % fill in the value for each variable.
    %   Note that each slab of output is a separate variable in the
    %   netcdf file, whether it comes from a 2D or 3D output in CESM.
    disp(sprintf('Writing %s to %s',vname,ncWPS))
    ncwrite(ncWPS,vname,value)
  end

