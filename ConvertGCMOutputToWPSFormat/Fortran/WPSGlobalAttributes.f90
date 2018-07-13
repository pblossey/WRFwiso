module WPSGlobalAttributes

  use netcdf
  implicit none

  integer :: version ! Format version (must =5 for WPS format)

  character (len=9) :: datasource   ! Valid date for data YYYY:MM:DD_HH:00:00
  character (len=24) :: hdate   ! Valid date for data YYYY:MM:DD_HH:00:00

  integer :: nx, ny             ! x- and y-dimensions of 2-d array
  integer :: iproj              ! Code for projection of data in array:
  !     0 = cylindrical equidistant
  !     1 = Mercator
  !     3 = Lambert conformal conic
  !     4 = Gaussian
  !     5 = Polar stereographic

  integer :: nlats = -999    ! Number of latitudes north of equator (for Gaussian grids)
  real :: startlat = -999., startlon = -999.  ! Lat/lon of point in array indicated by startloc string
  real :: deltalat = -999., deltalon = -999.  ! Grid spacing, degrees
  real :: dx = -999., dy = -999.              ! Grid spacing, km
  real :: xlonc = -999.                 ! Standard longitude of projection
  real :: truelat1 = -999., truelat2 = -999.  ! True latitudes of projection
  real :: earth_radius = -999.          ! Earth radius, km

  ! Flag indicating whether winds are relative to source grid (TRUE) 
  !    or relative to earth (FALSE)
  logical :: is_wind_grid_rel = .false.

  ! Which point in array is given by startlat/startlon; 
  !    set either to 'SWCORNER' or 'CENTER  '
  character (len=8)  :: startloc      

  ! Source model / originating center
  character (len=32) :: map_source    


contains

  subroutine ReadWPSGlobalAttributes(ncid,ounit,fname)
    implicit none
    integer, intent(in) :: ncid
    integer, intent(out) :: ounit ! Unit number for file output
    character(LEN=40) :: fname

    real :: nx, ny

    integer :: status(54), ii
    real :: is_wind_grid_rel_real

    status(1) = nf90_get_att(ncid,nf90_global,'iproj',iproj)
    status(2) = nf90_get_att(ncid,nf90_global,'startloc',startloc)
    status(3) = nf90_get_att(ncid,nf90_global,'startlat',startlat)
    status(4) = nf90_get_att(ncid,nf90_global,'startlon',startlon)
    status(5) = nf90_get_att(ncid,nf90_global,'nx',nx)
    status(6) = nf90_get_att(ncid,nf90_global,'ny',ny)
    status(7) = nf90_get_att(ncid,nf90_global,'deltalat',deltalat)
    status(8) = nf90_get_att(ncid,nf90_global,'deltalon',deltalon)
    status(9) = nf90_get_att(ncid,nf90_global,'earth_radius',earth_radius)
    status(10) = nf90_get_att(ncid,nf90_global,'is_wind_grid_rel',is_wind_grid_rel_real)
    if(is_wind_grid_rel_real.gt.0.) is_wind_grid_rel = .true.

    status(11) = nf90_get_att(ncid,nf90_global,'map_source',map_source)

    status(12) = nf90_get_att(ncid,nf90_global,'ounit',ounit)

    status(13) = nf90_get_att(ncid,nf90_global,'version',version)
    status(14) = nf90_get_att(ncid,nf90_global,'datasource',datasource)
    status(15) = nf90_get_att(ncid,nf90_global,'hdate',hdate)


    do ii = 1,15
      if (status(ii).NE.nf90_noerr) write(*,*) ii, nf90_strerror(status(ii))
    end do

    fname = TRIM(datasource) // ':' // TRIM(hdate)

  end subroutine ReadWPSGlobalAttributes

end module WPSGlobalAttributes
