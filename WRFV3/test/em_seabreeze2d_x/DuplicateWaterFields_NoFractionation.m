clear all; define_constants

in.nc = 'wrfinput_d01';

% copy the clean (isotope-free) WRF input file to save a clean copy
eval(sprintf('!cp %s %s_NoWISO',in.nc,in.nc))

myschema = ncinfo(in.nc);
for k = 1:length(myschema.Variables(:))
  vnames{k} = myschema.Variables(k).Name;
end

blankvar = myschema.Variables(getnameidx(vnames,'QVAPOR'));

% no fractionation
wh = {'VAPOR','CLOUD','ICE','RAIN','SNOW','GRAUP'};
whiso = {'HDO','O18'};
for m = 1:length(wh)
  varname = sprintf('Q%s',wh{m})
  qq = ncread(in.nc,varname);
  for nn = 1:length(whiso)
    isoname = sprintf('%s_Q%s',whiso{nn},wh{m})

    % if this variable is not already in the file, add it
    if getnameidx(vnames,isoname)==0
      blankvar.Name = isoname;
      ncwriteschema(in.nc,blankvar)
    end

    % write data to file
    ncwrite(in.nc,isoname,qq);
  end
end

n = 1;
whiso = {'HDO','O18'};
for nn = 1:length(whiso)
  isoname = sprintf('R_%s_SURF',whiso{nn});
  disp(isoname)
  have_surf = true;
  try 
    r_surf = ncread(in.nc,isoname);
  catch
    have_surf = false;
  end

  if have_surf
    % set the surface fluxes to be non-fractionating
    r_surf = ones(size(r_surf));
    ncwrite(in.nc,isoname,r_surf);
  else
    disp(['No variable for surface water isotope ratio in ' ...
          in.nc]);
  end

  isoname = sprintf('R_%s_QFX',whiso{nn});
  disp(isoname)
  have_r_qfx = true;
  try 
    r_qfx = ncread(in.nc,isoname);
  catch
    have_r_qfx = false;
  end

  if have_r_qfx
    % set the land/sea ice surface fluxes to be non-fractionating
    r_qfx = ones(size(r_qfx));
    ncwrite(in.nc,isoname,r_qfx);
  else
    disp(['No variable for water isotope ratio of land/sea ice surface fluxes in ' ...
          in.nc]);
  end
end
