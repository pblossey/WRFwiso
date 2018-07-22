% CESM2WPSNetcdf.m: This script is intended to take CESM output
%   from the .cam.h*, .clm.h* and .cice.h* netcdf output files
%   and generate netcdf files for each output time that contain
%   exactly the data that will be included in the WPS Intermediate
%   format files.  A separate fortran program is included that
%   converts the special WPS-ready netcdf file into the binary
%   intermediate format required by WPS.
%
%  Author: Peter Blossey (pblossey@uw.edu), November 2017

pres_list = 100* [ 2001 1000:-25:900 850:-50:100 70 50 30 20 10 5];
%% Added 200100 for surface properties.  
%  num_metgrid_levels = 28

model = 'CESM';
tag = 'amip06a';
cam.nc = 'GCMOutput/amip06a.cam.h1.2007-05-26-00000.nc';

caminfo = ncinfo(cam.nc);
whdim = {'time','lon','lat','lev','date','datesec'};
for m = 1:length(whdim)
  cam.(whdim{m}) = double(ncread(cam.nc,whdim{m}));
  vname = sprintf('N%s',whdim{m});
  cam.(vname) = length(cam.(whdim{m}));
end

% loop through the times in the CAM file and generate a separate
%    WPS-ready netcdf file for each time.
for itime = 1:5 %cam.Ndate

  % format the time/date for WPS
  tmp = cam.date(itime);
  yyyy = floor(tmp/1e4); 
  mm = floor( (tmp - 1e4*yyyy) / 1e2);
  dd = floor(tmp - 1e2*mm - 1e4*yyyy);
  hh = round(cam.datesec(itime)/3600); 
  hdate = sprintf('%.4d-%.2d-%.2d_%.2d', ...
                         yyyy,mm,dd,hh);
  disp(hdate)

  cam.lat = double(ncread(cam.nc,'lat'));
  cam.lon = double(ncread(cam.nc,'lon'));

  % set up netcdf file with attributes.  Add variables later
  ncout = CreateCESMFiniteVolumeNetcdfSchema(model,hdate,cam.lon,cam.lat);
  ncfname = sprintf('../../Output/%s.nc',hdate);
  ncwriteschema(ncfname,ncout);

  cam.nc_cam_h0 = sprintf('GCMOutput/%s.cam.h0.climo.nc',tag);
  cam.nc_clm_h0 = sprintf('GCMOutput/%s.clm2.h0.climo.nc',tag);
  cam.nc_cice_h0 = sprintf('GCMOutput/%s.cice.h.climo.nc',tag);

  %   extract 2D fields and save WPS-ready versions in the new
  %   netcdf file: ncfname.
  n2D = GetCAM2DVariables(ncfname,cam,itime,hdate);

  % now extract slabs from 3D fields, each interpolated to a given
  % set of pressure levels.  Save these WPS-ready slabs to ncfname
  n3D = GetCAM3DVariables(ncfname,cam,itime,hdate,pres_list);

  %   extract 2D fields and save WPS-ready versions in the new
  %   netcdf file: ncfname.
  land2D = GetCLM2DVariables(ncfname,cam,itime,hdate);

  %   extract soil moisture/soil temperature fields from CLM output
  %   and save WPS-ready versions in the new netcdf file: ncfname.
  soil_depths = [0 0.1 0.4 1.0 2.0]; % edges of NOAH soil layers in meters
                                     %  num_metgrid_soil_levels = 4

  land3D = GetCLM3DVariables(ncfname,cam,itime,hdate,soil_depths);

  %   extract 2D fields and save WPS-ready versions in the new
  %   netcdf file: ncfname.
  ice2D = GetCICE2DVariables(ncfname,cam,itime,hdate);

% $$$   if itime > 20; error('stop here'); end

end % itime = 1:cam.Ntime