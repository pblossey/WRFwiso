function [nout] = GetCAM2DVariables(ncWPS,cam,itime,hdate)

% function [] = GetCAM2DVariables(ncWPS,cam,itime,hdate)
%
%   reads several variables from CAM output netcdf files for a
%   particular output time and adds them to a specially-formatted
%   netcdf file that contains the information needed for these
%   variables to be output in Intermediate format for WRF WPS.
%
%   The input, cam, is a structure holding useful information about
%   the setup of the run (e.g, Nlon, Nlat, etc.)


  %  Get a list of 2D fields from CAM to be output.
  %  Some of these are easily translated for WPS.  Others will
  %  require a bit of computation.
  
  %            CAM name    WPS name     WPS level
  cam.wh2D = {{'PS',        'PSFC     ',200100}, ...
              {'PSL',       'PMSL     ',201300}, ...
              {'LANDFRAC',  'LANDSEA  ',200100}, ...
              {'ICEFRAC',   'SEAICE   ',200100}, ...
              {'TS',        'SKINTEMP ',200100}, ...
              {'TREFHT',    'TT       ',200100}, ...
              {'QREFHT',    'RH       ',200100}, ...
              {'QFLX_HDO',  'DHDOQFX  ',200100}, ...
              {'QFLX_18O',  'DO18QFX  ',200100}, ...
              {'PRECT_HDOR','DHDOSURF ',201300}, ...
              {'PRECT_H218OR','DO18SURF ',201300} };

  nout = 0;
  for m = 1:length(cam.wh2D)
    nout = nout + 1;

    CAMname = cam.wh2D{m}{1};
    WPSname = cam.wh2D{m}{2};
    xlvl = cam.wh2D{m}{3};

    start = [1 1 itime];
    count = [cam.Nlon cam.Nlat 1];
    var_in = double(ncread(cam.nc,CAMname,start,count));

    switch WPSname
      case {'RH       '}
       % compute RH with respect to liquid for reference height
       ps = double(ncread(cam.nc,'PS',start,count));
       T = double(ncread(cam.nc,'TREFHT',start,count));
       qv = double(ncread(cam.nc,'QREFHT',start,count));

       qv = qv./(1 - qv); % convert from specific humidity to mass
                          % mixing ratio

       value = qv./qsw(ps,T);

      case {'DHDOQFX  '}

       % compute delta18O of surface fluxes based on the isotopic
       % content of precipitation from a monthly climatology.  
       % Probably okay for sea ice/antarctica.  
       %  Should revisit for land areas north of antarctica.
       prect = double(ncread(cam.nc_cam_h0,'PRECT'));
       prect_HDO = double(ncread(cam.nc_cam_h0,'PRECT_HDOR'));

       value = 1000*(prect_HDO./prect - 1);

      case {'DO18QFX  '}

       % compute deltaD of surface fluxes based on the isotopic
       % content of precipitation.  Probably okay for sea
       % ice/antarctica.  Should revisit for land areas north of antarctica.
       prect = double(ncread(cam.nc_cam_h0,'PRECT'));
       prect_H218O = double(ncread(cam.nc_cam_h0,'PRECT_H218OR'));

       value = 1000*(prect_H218O./prect - 1);

       % TODO: I get a few weird values for dex using this
       % approach, though it is smoother across land-ocean
       % boundaries than the deltaD/delta18O of QFLX.
       % Should we 
       %    - smooth local anomalies in space?
       %    - use QFLX instead of PRECT away from Antarctica?
       %    - restrict dex to reasonable values (|dex|<60 per mil?)
       
% $$$        % compute deltaD of surface fluxes based on monthly mean values.
% $$$         qflx = double(ncread(cam.nc_cam_h0,'QFLX'));
% $$$         qflx_HDO = double(ncread(cam.nc_cam_h0,'QFLX_HDO'));
% $$$         qflx_18O = double(ncread(cam.nc_cam_h0,'QFLX_18O'));

       case {'DHDOSURF '}
        value = zeros(size(var_in));
       case {'D18OSURF '}
        value = zeros(size(var_in));

     otherwise
      value = var_in;
    end

    if ~isempty(find(isnan(value)))
      disp(sprintf('%d locations for %s are unfilled',length(find(isnan(value))),CAMname))
    end

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
    vinfo.Attributes(ii).Value = ncreadatt(cam.nc,CAMname,'units');
    ii = ii + 1;
    vinfo.Attributes(ii).Name = 'desc';
    vinfo.Attributes(ii).Value = ncreadatt(cam.nc,CAMname,'long_name');
    ii = ii + 1;

    ncwriteschema(ncWPS,vinfo);

    % fill in the value for each variable.
    %   Note that each slab of output is a separate variable in the
    %   netcdf file, whether it comes from a 2D or 3D output in CESM.
    disp(sprintf('Writing %s to %s',vname,ncWPS))
    ncwrite(ncWPS,vname,value)
  end

