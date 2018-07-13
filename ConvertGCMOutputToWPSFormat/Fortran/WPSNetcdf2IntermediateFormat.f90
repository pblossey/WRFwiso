program WPSNetcdf2IntermediateFormat
  use netcdf
  use WPSGlobalAttributes ! Information about GCM Grid/model for metgrid.exe.
  implicit none

  character(len=80) :: ncname
  character(LEN=40) :: fname
  integer :: ncid, status(10), ounit, ierr, varid
  integer :: nDim, nVar, nAtt

  real :: xfcst                 ! Forecast hour of data
  real :: xlvl                  ! Vertical level of data in 2-d array
  character (len=9) :: field   ! Name of the field
  character (len=25) :: units   ! Units of data
  character (len=46) :: desc    ! Short description of data

  real, dimension(:,:), allocatable :: slab      ! The 2-d array holding the data

  ! get netcdf file name from command line argument.
  if(COMMAND_ARGUMENT_COUNT().eq.0) then
    write(*,*) 'ERROR: Specify name of WPS-formatted netcdf as command line argument'
    STOP 'in WPSNetcdf2IntermediateFormat'
  end if
  call getarg(1,ncname) ! get netcdf filename

  ierr = nf90_open(ncname,nf90_nowrite,ncid)
  if(ierr.ne.nf90_noerr) write(*,*) 'open ', nf90_strerror(ierr)

  call ReadWPSGlobalAttributes(ncid,ounit,fname)

  write(*,*) TRIM(fname)

  open(unit=ounit,file=fname,form='unformatted')

  ierr = nf90_inquire(ncid,nDim,nVar,nAtt)
  if(ierr.ne.nf90_noerr)   write(*,*) 'inquire ', nf90_strerror(ierr)

  write(*,*) nDim, nVar, nAtt

  ALLOCATE(slab(nx,ny), STAT=ierr)
  if(ierr.ne.0) STOP 'Could not allocate slab'

  do varid = 1,nVar
    status(1) = nf90_get_att(ncid,varid,'WPSname',field)
    status(2) = nf90_get_att(ncid,varid,'xlvl',xlvl)
    status(3) = nf90_get_att(ncid,varid,'xfcst',xfcst)
    status(4) = nf90_get_att(ncid,varid,'units',units)
    status(5) = nf90_get_att(ncid,varid,'desc',desc)
    status(6) = nf90_get_var(ncid,varid,slab)

    write(*,*) field, units, desc, xlvl
    call DumpIntermediateFormat(ounit,xfcst,xlvl,slab,field,units,desc)

  end do
  DEALLOCATE(slab, STAT=ierr)
  if(ierr.ne.0) STOP 'Could not deallocate slab'

  close(unit=ounit)

  ierr = nf90_close(ncid)
  if(ierr.ne.nf90_noerr) write(*,*) 'close ', nf90_strerror(ierr)


end program WPSNetcdf2IntermediateFormat
