!bloss(2015-07-23): Code for outputing Intermediate Format files
!for WRF Preprocessing System (WPS) comes from
!
!  http://www2.mmm.ucar.edu/wrf/users/docs/user_guide/users_guide_chap3.html
!
!--->This should be compiled so that the binary output is big-endian.<---
!
!bloss(2017-10): Modified to clean up interface by using a module that contains all of 
!   the grid properties.

subroutine DumpIntermediateFormat(ounit,xfcst,xlvl,slab, field,units,desc)

  use WPSGlobalAttributes ! Information about GCM Grid for metgrid.exe.

  implicit none

  !inputs

  integer, intent(in) :: ounit              ! Unit number for file output
  real, intent(in) :: xfcst                 ! Forecast hour of data
  real, intent(in) :: xlvl                  ! Vertical level of data in 2-d array
  real, dimension(nx,ny), intent(in) :: slab      ! The 2-d array holding the data
  character (len=9) , intent(in) :: field   ! Name of the field
  character (len=25), intent(in) :: units   ! Units of data
  character (len=46), intent(in) :: desc    ! Short description of data

  !local variables
  logical :: file_is_open

  !check to see if file is open   
  INQUIRE(UNIT=ounit,OPENED=file_is_open)

!!$  write(*,*) 'In DumpIntermediateFormat.f90, file_is_open = ', file_is_open

  if(.NOT.file_is_open) then
    STOP 'Error in DumpIntermediateFormat.f90: Output file is not open'
  end if

  !  1) WRITE FORMAT VERSION
  write(unit=ounit) version

  !  2) WRITE METADATA
  ! Cylindrical equidistant
  if (iproj == 0) then
    write(unit=ounit) hdate, xfcst, map_source, field, &
         units, desc, xlvl, nx, ny, iproj
    write(unit=ounit) startloc, startlat, startlon, &
         deltalat, deltalon, earth_radius

    ! Mercator
  else if (iproj == 1) then
    write(unit=ounit) hdate, xfcst, map_source, field, &
         units, desc, xlvl, nx, ny, iproj
    write(unit=ounit) startloc, startlat, startlon, dx, dy, &
         truelat1, earth_radius

    ! Lambert conformal
  else if (iproj == 3) then
    write(unit=ounit) hdate, xfcst, map_source, field, &
         units, desc, xlvl, nx, ny, iproj
    write(unit=ounit) startloc, startlat, startlon, dx, dy, &
         xlonc, truelat1, truelat2, earth_radius

    ! Gaussian
  else if (iproj == 4) then
    write(unit=ounit) hdate, xfcst, map_source, field, &
         units, desc, xlvl, nx, ny, iproj
    write(unit=ounit) startloc, startlat, startlon, &
         nlats, deltalon, earth_radius

    ! Polar stereographic
  else if (iproj == 5) then
    write(unit=ounit) hdate, xfcst, map_source, field, &
         units, desc, xlvl, nx, ny, iproj
    write(unit=ounit) startloc, startlat, startlon, dx, dy, &
         xlonc, truelat1, earth_radius

  end if

  !  3) WRITE WIND ROTATION FLAG
  write(unit=ounit) is_wind_grid_rel

  !  4) WRITE 2-D ARRAY OF DATA
  write(unit=ounit) slab

end subroutine DumpIntermediateFormat
