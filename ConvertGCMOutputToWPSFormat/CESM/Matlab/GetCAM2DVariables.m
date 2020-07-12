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

target_time = mod(double(ncread(cam.nc,'time',itime,1)),365); % day of year                                                          
if ~isempty(strfind(cam.nc_cam_h0,'climo'))
  target_time = mod(target_time,365); % day of year                                                          
end


  %  Get a list of 2D fields from CAM to be output.
  %  Some of these are easily translated for WPS.  Others will
  %  require a bit of computation.
  
  %            CAM name    WPS name     WPS level
  cam.wh2D = {{'PS',        'PSFC     ',200100}, ...
              {'PSL',       'PMSL     ',201300}, ...
              {'LANDFRAC',  'LANDSEA  ',200100}, ...
              {'OCNFRAC',   'OCNFRAC  ',200100}, ...
              {'TS',        'SKINTEMP ',200100}, ...
              {'TS',  'DHDOQFX  ',200100}, ...
              {'TS',  'DO18QFX  ',200100}, ...
              {'TS','DHDOSURF ',201300}, ...
              {'TS','DO18SURF ',201300} };
% $$$               {'QFLX_HDO',  'DHDOQFX  ',200100}, ...
% $$$               {'QFLX_18O',  'DO18QFX  ',200100}, ...
% $$$               {'TREFHT',    'TT       ',200100}, ...
% $$$               {'QREFHT',    'RH       ',200100}, ...

  nout = 0;
  for m = 1:length(cam.wh2D)
    nout = nout + 1;

    ncfile = cam.nc;
    CAMname = cam.wh2D{m}{1};
    WPSname = cam.wh2D{m}{2};
    xlvl = cam.wh2D{m}{3};

    disp(sprintf('%s %s',CAMname,WPSname))

    Nlat_requested = length(cam.latind);
    Nlon_requested = length(cam.lonind);

% $$$     start = [1 1 itime];
% $$$     count = [cam.Nlon cam.Nlat 1];
    start = [cam.lonind(1) cam.latind(1) itime];
    count = [Nlon_requested Nlat_requested 1];
    try var_in = ncread(cam.nc,CAMname,start,count);
    catch
      if ~isempty(strfind(CAMname,'PRECT'))
        % try stripping the R off the end of the variable name
        try var_in = ncread(cam.nc,CAMname(1:end-1),start,count);
        catch
          continue
        end
        CAMname = CAMname(1:end-1);
      else
        time_h0 = double(ncread(cam.nc_cam_h0,'time'));
        start = [cam.lonind(1) cam.latind(1) 1];
        count = [Nlon_requested Nlat_requested length(time_h0)];

        % get the field from the monthly 2D output
        try var = ncread(cam.nc_cam_h0,CAMname,start,count);
        catch
          disp(sprintf(['Could not find %s in either *.cam.h*.nc ' ...
                        'file.  Will not supply %s to WPS.'],CAMname,strtrim(WPSname)))
          continue
        end

        ncfile = cam.nc_cam_h0;

        i1 = max(find(time_h0<target_time));
        if isempty(i1) 
          i1=1; i2 = 1; % target_time < min(time_h0), extrapolate
                        % from initial value
          w1 = 1;
        elseif target_time > max(time_h0)
          i2 = i1; % extrapolate from final value
          w1 = 1;
        else        
          i2 = i1+1; 
          w1 = (time_h0(i1+1)-target_time)/diff(time_h0(i1:i2));
        end
        w2 = 1 - w1;
        
%disp(time_h0)
%disp(sprintf('Target_time = %.3g, i1/i2 = %d %d, w1/w2 = %g %g', ...
%	     target_time,i1,i2,w1,w2))

        var_in = squeeze(w1*var(:,:,i1) + w2*var(:,:,i2));
        clear var
      end
    end
    var_in = double(var_in);

    switch WPSname
     case {'SKINTEMP '}
      % require that reported skin temperature be above 175K
      %   apparently, some six-hourly temperatures from CAM fail on the TS<170K check in WPS
      value = max(175,var_in);

     case {'RH       '}
      % compute RH with respect to liquid for reference height
      ps = double(ncread(cam.nc,'PS',start,count));
      T = double(ncread(cam.nc,'TREFHT',start,count));
      qv = double(ncread(cam.nc,'QREFHT',start,count));

      qv = qv./(1 - qv); % convert from specific humidity to mass
                         % mixing ratio

      value = qv./qsw(ps,T);

     case {'DHDOQFX  '}

      % compute a potential value for the deltaD of surface fluxes
      %   in two different ways:
      %     - based on the isotopic content of precipitation,
      %     - based on the isotopic content of near-surface soil
      %           water and snow cover.  
      % Here, we are implicitly assuming a non-fractionating flux
      % of water from the land surface into the atmosphere.  This
      % should work for ice-covered surfaces (sea ice/polar land) and
      % places where most of the surface moisture flux is transpiration.
      % We are interpolating from monthly averages or a monthly
      % climatology, which will keep the forcings be smaooth from
      % month to month. 
      %
      %  Ideally, we would compute this from the climatology of the
      %  upwards surface moisture flux for both standard water and
      %  its isotopic variants, but people mostly output the net
      %  moisture flux and often neglect to output the isotopic fluxes.
      time = double(ncread(cam.nc_cam_h0,'time'));
      prect = squeeze(interp1(time, ...
                              permute(double(ncread(cam.nc_cam_h0,'PRECT')),[3 1 2]), ...
                              target_time,'linear','extrap'));
      try prect_in = ncread(cam.nc_cam_h0,'PRECT_HDOR');
      catch
        prect_in = ncread(cam.nc_cam_h0,'PRECT_HDO');
      end
      prect_HDO = squeeze(interp1(time,permute(double(prect_in),[3 1 2]), ...
                                    target_time,'linear','extrap'));

      value = 1000*( (prect_HDO-prect)./(eps + prect) );

      % trim to size
      value = value(:,cam.latind);
      value = value(cam.lonind,:);

      % SOIL WATER AND SNOW
      time = double(ncread(cam.nc_cam_h0,'time'));
      skip_soilsnow = false;
      try soilsnow = ncread(cam.nc_clm_h0,'SNOWLIQ_H2OTR') ...
            + ncread(cam.nc_clm_h0,'SNOWICE_H2OTR') ...
            + ncread(cam.nc_clm_h0,'SOILLIQICE_10CM_H2OTR');
      catch
        skip_soilsnow = true;
      end

      if ~skip_soilsnow
        soilsnow_HDO = ncread(cam.nc_clm_h0,'SNOWLIQ_HDO') ...
            + ncread(cam.nc_clm_h0,'SNOWICE_HDO') ...
            + ncread(cam.nc_clm_h0,'SOILLIQICE_10CM_HDO');
        value_SOILSNOW = 1000*( (soilsnow_HDO-soilsnow)./(eps + soilsnow) );

        % only use the soilsnow delta over full land points
        landfrac = ncread(cam.nc_cam_h0,'LANDFRAC');
        value_SOILSNOW(soilsnow==0 | landfrac<1) = NaN;

        % trim to size
        value_SOILSNOW = value_SOILSNOW(:,cam.latind);
        value_SOILSNOW = value_SOILSNOW(cam.lonind,:);

        ind = find(~isnan(value_SOILSNOW));
        value(ind) = value_SOILSNOW(ind);
      end

      % apply physically-based but arbitrary limits on surface flux isotope ratios
      value(value<-600) = -600;
      value(value>100) = 100;

     case {'DO18QFX  '}

      % compute a potential value for the deltaD of surface fluxes
      %   in two different ways:
      %     - based on the isotopic content of precipitation,
      %     - based on the isotopic content of near-surface soil
      %           water and snow cover.  
      % Here, we are implicitly assuming a non-fractionating flux
      % of water from the land surface into the atmosphere.  This
      % should work for ice-covered surfaces (sea ice/polar land) and
      % places where most of the surface moisture flux is transpiration.
      % We are interpolating from monthly averages or a monthly
      % climatology, which will keep the forcings be smaooth from
      % month to month. 
      %
      %  Ideally, we would compute this from the climatology of the
      %  upwards surface moisture flux for both standard water and
      %  its isotopic variants, but people mostly output the net
      %  moisture flux and often neglect to output the isotopic fluxes.
      time = double(ncread(cam.nc_cam_h0,'time'));
      prect = squeeze(interp1(time, ...
                              permute(double(ncread(cam.nc_cam_h0,'PRECT')),[3 1 2]), ...
                              target_time,'linear','extrap'));
      try prect_in = ncread(cam.nc_cam_h0,'PRECT_H218OR');
      catch
        prect_in = ncread(cam.nc_cam_h0,'PRECT_H218O');
      end
      prect_H218O = squeeze(interp1(time,permute(double(prect_in),[3 1 2]), ...
                                    target_time,'linear','extrap'));

      value = 1000*( (prect_H218O-prect)./(eps + prect) );

      % trim to size
      value = value(:,cam.latind);
      value = value(cam.lonind,:);

      % SOIL WATER AND SNOW
      time = double(ncread(cam.nc_cam_h0,'time'));
      skip_soilsnow = false;
      try soilsnow = ncread(cam.nc_clm_h0,'SNOWICE_H2OTR') ...
            + ncread(cam.nc_clm_h0,'SNOWICE_H2OTR') ...
            + ncread(cam.nc_clm_h0,'SOILLIQICE_10CM_H2OTR');
      catch
        skip_soilsnow = true;
      end

      if ~skip_soilsnow
        soilsnow_H218O = ncread(cam.nc_clm_h0,'SNOWICE_H218O') ...
            + ncread(cam.nc_clm_h0,'SNOWICE_H218O') ...
            + ncread(cam.nc_clm_h0,'SOILLIQICE_10CM_H218O');
        value_SOILSNOW = 1000*( (soilsnow_H218O-soilsnow)./(eps + soilsnow) );

        % only use the soilsnow delta over full land points
        landfrac = ncread(cam.nc_cam_h0,'LANDFRAC');
        value_SOILSNOW(soilsnow==0 | landfrac<1) = NaN;

        % trim to size
        value_SOILSNOW = value_SOILSNOW(:,cam.latind);
        value_SOILSNOW = value_SOILSNOW(cam.lonind,:);

        ind = find(~isnan(value_SOILSNOW));
        value(ind) = value_SOILSNOW(ind);
      end

      % apply physically-based but arbitrary limits on surface flux isotope ratios
      value(value<-80) = -80;
      value(value>15) = 15;

     case {'DHDOSURF '}
      % this applies to evaporation water, so that the value of
      % zero seems appropriate for oceans.
      value = zeros(size(var_in));
     case {'DO18SURF '}
      % this applies to evaporation water, so that the value of
      % zero seems appropriate for oceans.
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
    vinfo.Attributes(ii).Value = ncreadatt(ncfile,CAMname,'units');
    ii = ii + 1;
    vinfo.Attributes(ii).Name = 'desc';
    vinfo.Attributes(ii).Value = ncreadatt(ncfile,CAMname,'long_name');
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

