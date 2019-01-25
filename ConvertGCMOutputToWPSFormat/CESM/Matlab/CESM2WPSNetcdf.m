function [] = CESM2WPSNetcdf(model,runtag,h0tag,cam_h1_filename, ...
                             lat_min,lat_max,lon_min,lon_max, ...
                             syy,smm,sdd,eyy,emm,edd);

% CESM2WPSNetcdf.m: This script is intended to take CESM output
%   from the .cam.h*, .clm.h* and .cice.h* netcdf output files
%   and generate netcdf files for each output time that contain
%   exactly the data that will be included in the WPS Intermediate
%   format files.  A separate fortran program is included that
%   converts the special WPS-ready netcdf file into the binary
%   intermediate format required by WPS.
%
%  Author: Peter Blossey (pblossey@uw.edu), November 2017

tic

  cam.quiet = true;

  pres_list = 100* [ 2001 1000:-25:900 850:-50:100 70 50 30 20 10 5];
  %% Added 200100 for surface properties.  
  %  num_metgrid_levels = 28

  cam.nc = sprintf('GCMOutput/%s',cam_h1_filename);

  caminfo = ncinfo(cam.nc);
  whdim = {'time','lon','lat','lev','date','datesec'};
  for m = 1:length(whdim)
    cam.(whdim{m}) = double(ncread(cam.nc,whdim{m}));
    vname = sprintf('N%s',whdim{m});
    cam.(vname) = length(cam.(whdim{m}));
  end

  % coordinates
  cam.lat = double(ncread(cam.nc,'lat'));
  cam.lon = double(ncread(cam.nc,'lon'));

  % trim coordinates
  cam.lat_min = lat_min; cam.lat_max = lat_max;
  cam.latind = find(cam.lat>=lat_min & cam.lat <= lat_max);
  cam.lat = cam.lat(cam.latind);

  cam.lon_min = lon_min; cam.lon_max = lon_max;
  cam.lonind = find(cam.lon>=lon_min & cam.lon <= lon_max);
  cam.lon = cam.lon(cam.lonind);

  % monthly climatologies for CAM, CLM, CICE
  cam.nc_cam_h0 = sprintf('GCMOutput/%s.cam.h0.%s.nc',runtag,h0tag);
  cam.nc_clm_h0 = sprintf('GCMOutput/%s.clm2.h0.%s.nc',runtag,h0tag);
  cam.nc_cice_h0 = sprintf('GCMOutput/%s.cice.h.%s.nc',runtag,h0tag);

  %   extract soil moisture/soil temperature climatologies from CLM output
  soil_depths = [0 0.1 0.4 1.0 2.0]; % edges of NOAH soil layers in meters
                                     %  num_metgrid_soil_levels = 4

  clm = GetCLMClimatologies(cam,soil_depths);

  %   extract sea ice climatologies from CICE output
  cice = GetCICEClimatologies(cam);

  % loop through the times in the CAM file and generate a separate
  %    WPS-ready netcdf file for each time.
  for itime = 1:cam.Ndate

    % format the time/date for WPS
    tmp = cam.date(itime);
    yyyy = floor(tmp/1e4); 
    mm = floor( (tmp - 1e4*yyyy) / 1e2);
    dd = floor(tmp - 1e2*mm - 1e4*yyyy);
    hh = round(cam.datesec(itime)/3600); 

sdate = 1e4*syy + 1e2*smm + sdd;
edate = 1e4*eyy + 1e2*emm + edd;

current_date = 1e4*yyyy + 1e2*mm + dd;

    if current_date >= sdate & current_date <= edate
      % We are within the start/end dates, so process the CESM data!

      hdate = sprintf('%.4d-%.2d-%.2d_%.2d', ...
                      yyyy,mm,dd,hh);
      disp(hdate)

      % set up netcdf file with attributes.  Add variables later
      ncout = CreateCESMFiniteVolumeNetcdfSchema(model,hdate,cam.lon,cam.lat);
      ncfname = sprintf('../../Output/%s.nc',hdate);
      ncwriteschema(ncfname,ncout);

      cam.ncfname{itime} = ncfname;
      cam.hdate{itime} = hdate;
      
      %   extract 2D fields and save WPS-ready versions in the new
      %   netcdf file: ncfname.
      tic
        n2D = GetCAM2DVariables(ncfname,cam,itime,hdate);
        disp('CAM2D')
      toc

      % now extract slabs from 3D fields, each interpolated to a given
      % set of pressure levels.  Save these WPS-ready slabs to ncfname
      tic
        n3D = GetCAM3DVariables(ncfname,cam,itime,hdate,pres_list);
        disp('CAM3D')
      toc

      %   extract 2D fields and save WPS-ready versions in the new
      %   netcdf file: ncfname.
      tic
        land2D = GetCLM2DVariables(ncfname,cam,clm,itime,hdate);
        disp('CLM2D')
      toc

      %   extract soil moisture/soil temperature fields from CLM output
      %   and save WPS-ready versions in the new netcdf file: ncfname.
      soil_depths = [0 0.1 0.4 1.0 2.0]; % edges of NOAH soil layers in meters
                                         %  num_metgrid_soil_levels = 4

      tic
        land3D = GetCLM3DVariables(ncfname,cam,clm,itime,hdate,soil_depths);
        disp('CLM3D')
      toc

      %   extract 2D fields and save WPS-ready versions in the new
      %   netcdf file: ncfname.
      tic
        ice2D = GetCICE2DVariables(ncfname,cam,cice,itime,hdate);
        disp('CICE2D')
      toc

    end

% $$$   if itime > 20; error('stop here'); end

end % itime = 1:cam.Ntime





toc
