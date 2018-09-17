function [nout] = GetCAM3DVariables(ncWPS,cam,itime,hdate,pres_list)

% function [] = GetCAM3DVariables(ncWPS,cam,itime,hdate,pres_list)
%
%   reads several variables from CAM output netcdf files for a
%   particular output time and adds them to a specially-formatted
%   netcdf file that contains the information needed for these
%   variables to be output in Intermediate format for WRF WPS.
%
%   The input, cam, is a structure holding useful information about
%   the setup of the run (e.g, Nlon, Nlat, etc.)

start = [1 1 itime];
count = [cam.Nlon cam.Nlat 1];
PS = double(ncread(cam.nc,'PS',start,count));
P0 = double(ncread(cam.nc,'P0'));
hyam = double(ncread(cam.nc,'hyam'));
hybm = double(ncread(cam.nc,'hybm'));

% compute the 3D pressure field on the GCM hybrid vertical grid
for ilev = 1:cam.Nlev
  pres(ilev,:,:) = P0*hyam(ilev) + PS*hybm(ilev);
end

%  Get a list of 3D fields from CAM to be output.
%  Some of these are easily translated for WPS.  Others will
%  require a bit of computation.

%            CAM name    WPS name     WPS level
cam.wh3D = {{'U',     'UU       '}, ...
            {'V',     'VV       '}, ...
            {'Z3',    'GHT      '}, ...
            {'T',     'TT       '}, ...
            {'Q',     'RH       '}, ...
            {'HDOV',  'DHDOV    '}, ...
            {'H218OV','DO18V    '} };


% read in each of the 3D fields.  Add them to the tmp structure
%     with the name from the CAM output file.
clear tmp
for m = 1:length(cam.wh3D)
  CAMname = cam.wh3D{m}{1};

  start = [1 1 1 itime];
  count = [cam.Nlon cam.Nlat cam.Nlev 1];
  tmp.(CAMname) = permute( ...
      double(ncread(cam.nc,CAMname,start,count)), [3 1 2]);
end

% compute deltas for isotopes.
tmp.deltaD = 1000*(tmp.HDOV./tmp.Q - 1);
tmp.deltaO18 = 1000*(tmp.H218OV./tmp.Q - 1);

% now go through the fields and interpolate onto the pressures in pres_list
nout = 0;
for m = 1:length(cam.wh3D)
  CAMname = cam.wh3D{m}{1};
  WPSname = cam.wh3D{m}{2};

  % copy pres_list into a temporary variable, so that the first
  % entry (200100) can be replaced with the surface pressure in
  % each column.
  tmp_pres = pres_list; 

  switch CAMname
   case {'Q'} % --> output RH for WPS
              % compute RH with respect to liquid for reference height
    for ilat = 1:cam.Nlat
      for ilon = 1:cam.Nlon
        tmp_pres(1) = PS(ilon,ilat);

        TT = interp1(pres(:,ilon,ilat),tmp.T(:,ilon,ilat), ...
                     tmp_pres,'linear', ...
                     tmp.T(end,ilon,ilat) );
        QQ = interp1(pres(:,ilon,ilat),tmp.Q(:,ilon,ilat), ...
                     tmp_pres,'linear', ...
                     tmp.Q(end,ilon,ilat) ); 

        QQ = QQ./(1 - QQ); % convert from specific humidity to mass
                           % mixing ratio
        value3D(:,ilon,ilat) = 100.*QQ./qsw(tmp_pres,TT);
      end
    end

    units_txt = 'Relative humidity'; %%ncreadatt(cam.nc,CAMname,'units');
    desc_txt = 'percent'; %%ncreadatt(cam.nc,CAMname,'long_name');

   case {'HDOV'}% --> output deltaD for WPS
    
    for ilat = 1:cam.Nlat
      for ilon = 1:cam.Nlon
        tmp_pres(1) = PS(ilon,ilat);

        DD = interp1(pres(:,ilon,ilat),tmp.deltaD(:,ilon,ilat), ...
                     tmp_pres,'linear', ...
                     tmp.deltaD(end,ilon,ilat) ); 

        value3D(:,ilon,ilat) = DD;
      end
    end

    units_txt = 'deltaD of water vapor'; %%ncreadatt(cam.nc,CAMname,'units');
    desc_txt = 'per mil'; %%ncreadatt(cam.nc,CAMname,'long_name');

   case {'H218OV'}% --> output deltaO18 for WPS
    
    for ilat = 1:cam.Nlat
      for ilon = 1:cam.Nlon
        tmp_pres(1) = PS(ilon,ilat);

        DD = interp1(pres(:,ilon,ilat),tmp.deltaO18(:,ilon,ilat), ...
                     tmp_pres,'linear', ...
                     tmp.deltaO18(end,ilon,ilat) );

        value3D(:,ilon,ilat) = DD;
      end
    end

    units_txt = 'delta18O of water vapor'; %%ncreadatt(cam.nc,CAMname,'units');
    desc_txt = 'per mil'; %%ncreadatt(cam.nc,CAMname,'long_name');

   otherwise

    % extra a slice of the current field at pressure xlvl.
    for ilat = 1:cam.Nlat
      for ilon = 1:cam.Nlon
        tmp_pres(1) = PS(ilon,ilat);

        value3D(:,ilon,ilat) = interp1(pres(:,ilon,ilat),tmp.(CAMname)(:,ilon,ilat), ...
                                       tmp_pres,'linear', ...
                                       tmp.(CAMname)(end,ilon,ilat));
      end
    end

    units_txt = ncreadatt(cam.nc,CAMname,'units');
    desc_txt = ncreadatt(cam.nc,CAMname,'long_name');

  end

  if ~isempty(find(isnan(value3D)))
    disp(sprintf('%d locations for %s are unfilled',length(find(isnan(value3D))),CAMname))
  end


  for ilev = 1:length(pres_list)
    nout = nout + 1;
    xlvl = pres_list(ilev);

    value = squeeze(value3D(ilev,:,:));

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
    if ~cam.quiet 
      disp(sprintf('Writing %s to %s',vname,ncWPS))
    end
    ncwrite(ncWPS,vname,value)
  end

end
