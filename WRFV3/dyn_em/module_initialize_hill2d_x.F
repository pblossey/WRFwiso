! sed -e "s/grid%mu/gridmu/g" -e "s/grid%Mu/gridMu/g" module_initialize_hill2d_x.F | cpp -DHYBRID_COORD | sed -e "s/gridmu/grid%mu/g" -e "s/gridMu/grid%Mu/g" >> module_initialize_hill2d_x.next
#if ( HYBRID_COORD==1 )
#  define gridmu_1(...) (grid%c1h(k)*XXPC1HXX(__VA_ARGS__))
#  define XXPC1HXX(...) grid%mu_1(__VA_ARGS__)

#  define gridMu_1(...) (grid%c1f(k)*XXPC1FXX(__VA_ARGS__))
#  define XXPC1FXX(...) grid%Mu_1(__VA_ARGS__)

#  define gridmub(...) (grid%c1h(k)*XXPCBHXX(__VA_ARGS__)+grid%c2h(k))
#  define XXPCBHXX(...) grid%mub(__VA_ARGS__)

#  define gridMub(...) (grid%c1f(k)*XXPCBFXX(__VA_ARGS__)+grid%c2f(k))
#  define XXPCBFXX(...) grid%Mub(__VA_ARGS__)
#endif

!IDEAL:MODEL_LAYER:INITIALIZATION
!

!  This MODULE holds the routines which are used to perform various initializations
!  for the individual domains.  

!  This MODULE CONTAINS the following routines:

!  initialize_field_test - 1. Set different fields to different constant
!                             values.  This is only a test.  If the correct
!                             domain is not found (based upon the "id")
!                             then a fatal error is issued.               

!-----------------------------------------------------------------------

MODULE module_initialize_ideal

   USE module_domain
   USE module_io_domain
   USE module_state_description
   USE module_model_constants
   USE module_bc
   USE module_timing
   USE module_configure
   USE module_init_utilities
#ifdef DM_PARALLEL
   USE module_dm
#endif


CONTAINS


!-------------------------------------------------------------------
! this is a wrapper for the solver-specific init_domain routines.
! Also dereferences the grid variables and passes them down as arguments.
! This is crucial, since the lower level routines may do message passing
! and this will get fouled up on machines that insist on passing down
! copies of assumed-shape arrays (by passing down as arguments, the 
! data are treated as assumed-size -- ie. f77 -- arrays and the copying
! business is avoided).  Fie on the F90 designers.  Fie and a pox.
! NOTE:  Modified to remove all but arrays of rank 4 or more from the 
!        argument list.  Arrays with rank>3 are still problematic due to the 
!        above-noted fie- and pox-ities.  TBH 20061129.  

   SUBROUTINE init_domain ( grid )

   IMPLICIT NONE

   !  Input data.
   TYPE (domain), POINTER :: grid 
   !  Local data.
   INTEGER :: idum1, idum2

   
   CALL set_scalar_indices_from_config ( head_grid%id , idum1, idum2 )

     CALL init_domain_rk( grid &
!
#include "actual_new_args.inc"
!
                        )

   END SUBROUTINE init_domain

!-------------------------------------------------------------------

   SUBROUTINE init_domain_rk ( grid &
!
# include "dummy_new_args.inc"
!
)
   IMPLICIT NONE

   !  Input data.
   TYPE (domain), POINTER :: grid

# include "dummy_new_decl.inc"

   TYPE (grid_config_rec_type)              :: config_flags

   !  Local data
   INTEGER                             ::                       &
                                  ids, ide, jds, jde, kds, kde, &
                                  ims, ime, jms, jme, kms, kme, &
                                  its, ite, jts, jte, kts, kte, &
                                  i, j, k, kk

   ! Local data

   INTEGER, PARAMETER :: nl_max = 1000
   REAL, DIMENSION(nl_max) :: zk, p_in, theta, rho, u, v, qv, pd_in
   INTEGER :: nl_in


   INTEGER :: icm,jcm, ii, im1, jj, jm1, loop, error, fid, nxc, nyc
   REAL    :: u_mean,v_mean, f0, p_surf, p_level, qvf, z_at_v, z_at_u
   REAL    :: z_scale, xrad, yrad, zrad, rad, delt, cof1, cof2
!   REAL, EXTERNAL :: interp_0
   REAL    :: hm, xa
   REAL    :: pi

!  stuff from original initialization that has been dropped from the Registry 
   REAL    :: vnu, xnu, xnus, dinit0, cbh, p0_temp, t0_temp, zd, zt
   REAL    :: qvf1, qvf2, pd_surf
   INTEGER :: it
   real :: thtmp, ptmp, temp(3)

   LOGICAL :: moisture_init
   LOGICAL :: stretch_grid, dry_sounding

   REAL    :: xa1, xal1,hm1  !  data for intercomparison setup from dale

   REAL    :: B1, B2, B3, B4, B5, sin_arg

   REAL    :: Nsq, z, z1, z2
   INTEGER :: iter_loop

!..Begin additions (bloss)

   ! G. Thompson additions for reading in vertical levels from external file
   LOGICAL :: read_grid_from_file
   INTEGER :: nlevels
   CHARACTER (LEN=16) :: file_eta_levels = 'sigmaw.dat'

   ! bloss additions for using namelist to specify topography and other parameters
   LOGICAL :: have_prm_file
   INTEGER :: ierr, ierr_missing_namelist, terrain_type
   REAL    :: hill_latitude, hill_longitude, placeholder, xarg

   !bloss: Supply parameters for topography and vertical grid through a
   !         namelist called "em_hill2d_x"
   NAMELIST /EM_HILL2D_X/ terrain_type, hm, xa, xa1, xal1, hm1, &
        stretch_grid, z_scale, hill_latitude, hill_longitude, &
        read_grid_from_file, file_eta_levels

   !bloss: Make a namelist that shouldn't ever be in the prm file.
   !  This lets you diagnose whether the namelist was missing or
   !  if there was an error reading the namelist.  My feeling is
   !  that there shouldn't be an error if the (optional) namelist is
   !  missing but that the run should stop if the EM_HILL2D_X namelist
   !  was in the file but there was an error reading it.
   NAMELIST /bydswioubnuOZBSda/ placeholder

!..End additions (bloss)

   SELECT CASE ( model_data_order )
         CASE ( DATA_ORDER_ZXY )
   kds = grid%sd31 ; kde = grid%ed31 ;
   ids = grid%sd32 ; ide = grid%ed32 ;
   jds = grid%sd33 ; jde = grid%ed33 ;

   kms = grid%sm31 ; kme = grid%em31 ;
   ims = grid%sm32 ; ime = grid%em32 ;
   jms = grid%sm33 ; jme = grid%em33 ;

   kts = grid%sp31 ; kte = grid%ep31 ;   ! note that tile is entire patch
   its = grid%sp32 ; ite = grid%ep32 ;   ! note that tile is entire patch
   jts = grid%sp33 ; jte = grid%ep33 ;   ! note that tile is entire patch
         CASE ( DATA_ORDER_XYZ )
   ids = grid%sd31 ; ide = grid%ed31 ;
   jds = grid%sd32 ; jde = grid%ed32 ;
   kds = grid%sd33 ; kde = grid%ed33 ;

   ims = grid%sm31 ; ime = grid%em31 ;
   jms = grid%sm32 ; jme = grid%em32 ;
   kms = grid%sm33 ; kme = grid%em33 ;

   its = grid%sp31 ; ite = grid%ep31 ;   ! note that tile is entire patch
   jts = grid%sp32 ; jte = grid%ep32 ;   ! note that tile is entire patch
   kts = grid%sp33 ; kte = grid%ep33 ;   ! note that tile is entire patch
         CASE ( DATA_ORDER_XZY )
   ids = grid%sd31 ; ide = grid%ed31 ;
   kds = grid%sd32 ; kde = grid%ed32 ;
   jds = grid%sd33 ; jde = grid%ed33 ;

   ims = grid%sm31 ; ime = grid%em31 ;
   kms = grid%sm32 ; kme = grid%em32 ;
   jms = grid%sm33 ; jme = grid%em33 ;

   its = grid%sp31 ; ite = grid%ep31 ;   ! note that tile is entire patch
   kts = grid%sp32 ; kte = grid%ep32 ;   ! note that tile is entire patch
   jts = grid%sp33 ; jte = grid%ep33 ;   ! note that tile is entire patch

   END SELECT

   stretch_grid = .true.
!   z_scale = .50
   z_scale = .40

   !..Begin addition (bloss)
   !bloss: set initial values for parameters that can be modified through
   !         EM_HILL2D_X namelist
   terrain_type = 1 ! 0=flat surface, 1=witch of Agnesi,
                    ! 2=gaussian*cosine hill, 3=cosine**4 hill

   ! terrain type==1, Witch of Agnesi
   hm = 100. ! height in m
   xa = 10.e3  ! half-width in m

   ! terrain type==2, gaussian*cosine hill
   hm1  = 250. ! height in m
   xa1  = 5000. ! half-width of gaussian in m
   xal1 = 4000. ! half-wavelength of cosine in m
   icm = ide/2

   ! vertical grid options
   read_grid_from_file = .false.
   ! lat/lon options (important for coriolis/radiation if enabled).
   hill_latitude = 40.
   hill_longitude = -105.

   ! check for file with namelist.  open and read in namelist if it exists.
   INQUIRE(FILE='prm',EXIST=have_prm_file)
   if(have_prm_file) then
     OPEN(UNIT=94,FILE='prm',FORM='formatted')
     READ(94,NML=EM_HILL2D_X,IOSTAT=ierr)
     if(ierr.eq.0) then
       write(6,*) 'Read EM_HILL2D_X namelist from prm file'
     else
       REWIND(94)
       READ(94,NML=bydswioubnuOZBSda,IOSTAT=ierr_missing_namelist)
       if(ierr_missing_namelist.eq.0) then
         write(6,*) 'Please remove the bydswioubnuOZBSda namelist from '
         write(6,*) ' your prm file.  Its absence is important in diagnosing'
         write(6,*) ' errors in reading the EM_HILL2D_X namelist.'
         STOP 'REMOVE bydswioubnuOZBSda NAMELIST FROM PRM FILE'
       end if
       if(ierr.eq.ierr_missing_namelist) then
         write(6,*) 'No EM_HILL2D_X namelist found in prm file'
         write(6,*) 'Running with default parameter choices'
       else
         write(6,*) 'Error reading EM_HILL2D_X namelist from prm file'
         READ(94,NML=EM_HILL2D_X)
       end if
     end if
     CLOSE(94)
   end if

   ! output useful information about terrain to standard output
   SELECT CASE (terrain_type)
     CASE (0)
       write(6,*) 'Terrain is flat ground: grid%ht(:,:) = 0.'
     CASE (1)
       write(6,992) hm
       write(6,993) xa
992    format('Terrain is a Witch of Agnesi mountain with height ',F8.2,' meters')
993    format('   and half-width ',F8.2,' meters.')
     CASE (2)
       write(6,994) hm1
       write(6,995) xa1, xal1
994    format('Terrain is a gaussian/cosine hill with height ',F8.2,' meters,')
995    format('   gaussian half-width ',F8.2,' meters, and cosine half-wavelength ',F8.2,' meters.')
     CASE (3)
       write(6,996) hm
       write(6,997) xa
996    format('Terrain is a cosine bell raised to the fourth power with height ',F8.2,' meters')
997    format('   and quarter width ',F8.2,' meters.')
     END SELECT
     write(6,*)
   !..End addition (bloss)

   pi = 2.*asin(1.0)
   write(6,*) ' pi is ',pi
   nxc = (ide-ids)/4
   nyc = (jde-jds)/2

   CALL model_to_grid_config_rec ( grid%id , model_config_rec , config_flags )

! here we check to see if the boundary conditions are set properly

   CALL boundary_condition_check( config_flags, bdyzone, error, grid%id )

   moisture_init = .true.

    grid%itimestep=0

#ifdef DM_PARALLEL
   CALL wrf_dm_bcast_bytes( icm , IWORDSIZE )
   CALL wrf_dm_bcast_bytes( jcm , IWORDSIZE )
#endif

    CALL nl_set_mminlu(1,'    ')
    CALL nl_set_iswater(1,0)
    CALL nl_set_cen_lat(1,hill_latitude) !bloss
    CALL nl_set_cen_lon(1,hill_longitude) !bloss
    CALL nl_set_truelat1(1,0.)
    CALL nl_set_truelat2(1,0.)
    CALL nl_set_moad_cen_lat (1,0.)
    CALL nl_set_stand_lon (1,0.)
    CALL nl_set_pole_lon (1,0.)
    CALL nl_set_pole_lat (1,90.)
    CALL nl_set_map_proj(1,0)


!  here we initialize data we currently is not initialized 
!  in the input data

    DO j = jts, jte
      DO i = its, ite
         grid%msftx(i,j)    = 1.
         grid%msfty(i,j)    = 1.
         grid%msfux(i,j)    = 1.
         grid%msfuy(i,j)    = 1.
         grid%msfvx(i,j)    = 1.
         grid%msfvx_inv(i,j)= 1.
         grid%msfvy(i,j)    = 1.
         grid%sina(i,j)     = 0.
         grid%cosa(i,j)     = 1.
         grid%e(i,j)        = 0.
         grid%f(i,j)        = 0.

      END DO
   END DO

    DO j = jts, jte
    DO k = kts, kte
      DO i = its, ite
         grid%ww(i,k,j)     = 0.
      END DO
   END DO
   END DO

   grid%step_number = 0

! set up the grid

   !..Begin addition
   IF (read_grid_from_file) THEN
     !bloss:  Use code supplied by Greg Thompson to reading in user-specified full sigma levels.
     open(unit=81,file=file_eta_levels,form='formatted',status='old')
     read(81,*) nlevels
     if(kde.ne.nlevels)then
       write(6,*) ' vertical level mismatch (kde ne nlevels) kde, nlevels ',kde, nlevels
       call wrf_error_fatal ( ' problem with vertical levels kde ne nlevels ' )
     endif
     do k=1, nlevels
       read(81,*) grid%znw(k)
       print*,'    k, znw(k)= ',k,grid%znw(k)
     enddo
     close(unit=81,status = 'keep')
     !..End addition
   ELSE

   IF (stretch_grid) THEN ! exponential stretch for eta (nearly constant dz)
     DO k=1, kde
      grid%znw(k) = (exp(-(k-1)/float(kde-1)/z_scale) - exp(-1./z_scale))/ &
                                (1.-exp(-1./z_scale))
     ENDDO
   ELSE
     DO k=1, kde
      grid%znw(k) = 1. - float(k-1)/float(kde-1)
     ENDDO
   ENDIF

   ENDIF !bloss

   DO k=1, kde-1
    grid%dnw(k) = grid%znw(k+1) - grid%znw(k)
    grid%rdnw(k) = 1./grid%dnw(k)
    grid%znu(k) = 0.5*(grid%znw(k+1)+grid%znw(k))
   ENDDO
   DO k=2, kde-1
    grid%dn(k) = 0.5*(grid%dnw(k)+grid%dnw(k-1))
    grid%rdn(k) = 1./grid%dn(k)
    grid%fnp(k) = .5* grid%dnw(k  )/grid%dn(k)
    grid%fnm(k) = .5* grid%dnw(k-1)/grid%dn(k)
   ENDDO

   cof1 = (2.*grid%dn(2)+grid%dn(3))/(grid%dn(2)+grid%dn(3))*grid%dnw(1)/grid%dn(2) 
   cof2 =     grid%dn(2)        /(grid%dn(2)+grid%dn(3))*grid%dnw(1)/grid%dn(3) 
   grid%cf1  = grid%fnp(2) + cof1
   grid%cf2  = grid%fnm(2) - cof1 - cof2
   grid%cf3  = cof2       

   grid%cfn  = (.5*grid%dnw(kde-1)+grid%dn(kde-1))/grid%dn(kde-1)
   grid%cfn1 = -.5*grid%dnw(kde-1)/grid%dn(kde-1)
   grid%rdx = 1./config_flags%dx
   grid%rdy = 1./config_flags%dy

!  get the sounding from the ascii sounding file, first get dry sounding and 
!  calculate base state

  write(6,*) ' getting dry sounding for base state '
  dry_sounding = .true.
  CALL get_sounding( zk, p_in, pd_in, theta, rho, u, v, qv, dry_sounding, &
                     nl_max, nl_in, .true.)

  write(6,*) ' returned from reading sounding, nl_in is ',nl_in


!  find ptop for the desired ztop (ztop is input from the namelist),
!  and find surface pressure

  grid%p_top = interp_0( p_in, zk, config_flags%ztop, nl_in )

!  Fill in the hybrid coordinate coefficients

   DO k=1, kde
      IF      ( config_flags%hybrid_opt .EQ. 0 ) THEN
         grid%c3f(k) = grid%znw(k)
      ELSE IF ( config_flags%hybrid_opt .EQ. 1 ) THEN
         grid%c3f(k) = grid%znw(k)
      ELSE IF ( config_flags%hybrid_opt .EQ. 2 ) THEN
         B1 = 2. * grid%etac**2 * ( 1. - grid%etac )
         B2 = -grid%etac * ( 4. - 3. * grid%etac - grid%etac**3 )
         B3 = 2. * ( 1. - grid%etac**3 )
         B4 = - ( 1. - grid%etac**2 )
         B5 = (1.-grid%etac)**4
         grid%c3f(k) = ( B1 + B2*grid%znw(k) + B3*grid%znw(k)**2 + B4*grid%znw(k)**3 ) / B5
         IF ( grid%znw(k) .LT. grid%etac ) THEN
            grid%c3f(k) = 0.
         END IF
         IF ( k .EQ. kds ) THEN
            grid%c3f(k) = 1.
         ELSE IF ( k .EQ. kde ) THEN
            grid%c3f(k) = 0.
         END IF
      ELSE IF ( config_flags%hybrid_opt .EQ. 3 ) THEN
         IF ( grid%znw(k) .GE. grid%etac ) THEN
            sin_arg = (1./(1.-grid%etac))*(grid%znw(k)-1.)+1
            grid%c3f(k) = (sin(sin_arg*3.14159265358/2.))**2
         ELSE
            grid%c3f(k) = 0.
         END IF
         IF ( k .EQ. kds ) THEN
            grid%c3f(k) = 1.
         ELSE IF ( k .EQ. kds ) THEN
            grid%c3f(kde) = 0.
         END IF
      ELSE
         CALL wrf_error_fatal ( 'ERROR: --- hybrid_opt=0 ===> Standard WRF Coordinate; hybrid_opt>=1 ===> Hybrid Vertical Coordinate' )
      END IF
   END DO

   DO k=1, kde
      grid%c4f(k) = ( grid%znw(k) - grid%c3f(k) ) * ( p1000mb - grid%p_top )
   ENDDO

   !  Now on half levels, just add up and divide by 2 (for c3h).  Use (eta-c3)*(p00-pt) for c4 on half levels.

   DO k=1, kde-1
      grid%c3h(k) = ( grid%c3f(k+1) + grid%c3f(k) ) * 0.5
      grid%c4h(k) = ( grid%znu(k) - grid%c3h(k) ) * ( p1000mb - grid%p_top )
   ENDDO

   !  c1 = d(B)/d(eta).  We define c1f as c1 on FULL levels.  For a vertical difference,
   !  we need to use B and eta on half levels.  The k-loop ends up referring to the 
   !  full levels, neglecting the top and bottom.

   DO k=kds+1, kde-1
      grid%c1f(k) = ( grid%c3h(k) - grid%c3h(k-1) ) / ( grid%znu(k) - grid%znu(k-1) )
   ENDDO

   !  The boundary conditions to get the coefficients:
   !  1) At k=kts: define d(B)/d(eta) = 1.  This gives us the same value of B and d(B)/d(eta)
   !     when doing the sigma-only B=eta.
   !  2) At k=kte: with the new vertical coordinate, define d(B)/d(eta) = 0.  The curve B SMOOTHLY 
   !     goes to zero, and at the very top, B continues to SMOOTHLY go to zero.  Note that for 
   !     almost all cases of non B=eta, B is ALREADY=ZERO at the top, so this is a reasonable BC to 
   !     assume.
   !  3) At k=kte: when trying to mimic the original vertical coordinate, since B = eta, then
   !     d(B)/d(eta) = 1.

   grid%c1f(kds) = 1.
   IF      ( ( config_flags%hybrid_opt .EQ. 0 ) .OR. ( config_flags%hybrid_opt .EQ. 1 ) ) THEN
      grid%c1f(kde) = 1.
   ELSE
      grid%c1f(kde) = 0.
   END IF

   !  c2 = ( 1. - c1(k) ) * (p00 - pt).  There is no vertical differencing, so we can do the
   !  full kds to kde looping.

   DO k=kds, kde
      grid%c2f(k) = ( 1. - grid%c1f(k) ) * ( p1000mb - grid%p_top )
   END DO

   !  Now on half levels for c1 and c2.  The c1h will result from the full level c3 and full
   !  level eta differences.  The c2 value use the half level c1(k).

   DO k=1, kde-1
      grid%c1h(k) = ( grid%c3f(k+1) - grid%c3f(k) ) / ( grid%znw(k+1) - grid%znw(k) )
      grid%c2h(k) = ( 1. - grid%c1h(k) ) * ( p1000mb - grid%p_top )
   END DO

#if 0
   DO k=1, kde
      grid%c3f(k) = grid%znw(k)
      grid%c4f(k) = 0.
      grid%c3h(k) = grid%znu(k)
      grid%c4h(k) = 0.
      grid%c1f(k) = 1.
      grid%c2f(k) = 0.
      grid%c1h(k) = 1.
      grid%c2h(k) = 0.
   END DO
#endif

  !..Begin addition (bloss): options for topography type controlled by namelist.
  DO j=jts,jte
    DO i=its,ite  
      grid%ht(i,j) = 0. ! initialize terrain to a flat surface with zero height.
    ENDDO
  ENDDO

  SELECT CASE (terrain_type) 
  CASE (0) 
    ! flat surface, nothing to do
  CASE (1) 
    ! Witch of Agnesi -- default
    DO j=jts,jte
      DO i=its,ite  
        grid%ht(i,j) = hm/(1.+(config_flags%dx*float(i-icm)/xa)**2)
      ENDDO
    ENDDO

  CASE (2) 
    ! gaussian-cosine blend
    !  comment above reads: data for intercomparison setup from dale
    DO j=jts,jte
      DO i=its,ite  
        grid%ht(i,j) = hm1*exp(-(( config_flags%dx*float(i-icm)/xa1)**2))   &
             *( (cos(pi*config_flags%dx*float(i-icm)/xal1))**2 )
      ENDDO
    ENDDO

  CASE (3) 
    ! cosine**4 bell
    !   Based on Muhlbauer et al (2010, ACP, doi:10.5194/acp-10-8173-2010)
    DO j=jts,jte
      DO i=its,ite  
        xarg = config_flags%dx*float(i-icm)
        if(ABS(xarg).lt.4.*xa) then ! mountain exists for |x-x0| < 4*a0, Muhl eqn 2.
          grid%ht(i,j) = (hm/16.)*( 1. + cos(pi*xarg/(4.*xa)) )**4
        end if
      ENDDO
    ENDDO

  CASE DEFAULT
    STOP 'Bad terrain_type in module_initialize_hill2d_x.F'
  END SELECT
  !..End addition

  DO j=jts,jte
  DO i=its,ite  
    grid%phb(i,1,j) = g*grid%ht(i,j)
    grid%php(i,1,j) = 0.
    grid%ph0(i,1,j) = grid%phb(i,1,j)
  ENDDO
  ENDDO

  DO J = jts, jte
  DO I = its, ite

    p_surf = interp_0( p_in, zk, grid%phb(i,1,j)/g, nl_in )
    grid%MUB(i,j) = p_surf-grid%p_top

!  this is dry hydrostatic sounding (base state), so given grid%p (coordinate),
!  interp theta (from interp) and compute 1/rho from eqn. of state

    DO K = 1, kte-1
#if  !( HYBRID_COORD==1 )
      p_level = grid%znu(k)*(p_surf - grid%p_top) + grid%p_top
#elif ( HYBRID_COORD==1 )
      p_level = grid%c3h(k)*(p_surf - grid%p_top) + grid%c4h(k) + grid%p_top
#endif
      grid%pb(i,k,j) = p_level
      grid%t_init(i,k,j) = interp_0( theta, p_in, p_level, nl_in ) - t0
      grid%alb(i,k,j) = (r_d/p1000mb)*(grid%t_init(i,k,j)+t0)*(grid%pb(i,k,j)/p1000mb)**cvpm
    ENDDO

!  calc hydrostatic balance (alternatively we could interp the geopotential from the
!  sounding, but this assures that the base state is in exact hydrostatic balance with
!  respect to the model eqns.

    DO kk  = 2,kte
      k=kk - 1
      grid%phb(i,kk,j) = grid%phb(i,kk-1,j) - grid%dnw(kk-1)*grid%mub(i,j)*grid%alb(i,kk-1,j)
    ENDDO

  ENDDO
  ENDDO

  write(6,*) ' ptop is ',grid%p_top
#if  !( HYBRID_COORD==1 )
  write(6,*) ' base state grid%mub(1,1), p_surf is ',grid%mub(1,1),grid%mub(1,1)+grid%p_top
#elif ( HYBRID_COORD==1 )
  write(6,*) ' base state grid%MUB(1,1), p_surf is ',grid%MUB(1,1),grid%c3f(kts)*grid%MUB(1,1)+grid%c4f(kts)+grid%p_top
#endif

!  calculate full state for each column - this includes moisture.

  write(6,*) ' getting moist sounding for full state '
  dry_sounding = .false.
  CALL get_sounding( zk, p_in, pd_in, theta, rho, u, v, qv, dry_sounding, &
                     nl_max, nl_in, .false. )

  DO J = jts, min(jde-1,jte)
  DO I = its, min(ide-1,ite)

!  At this point grid%p_top is already set. find the DRY mass in the column 
!  by interpolating the DRY pressure.  

   pd_surf = interp_0( pd_in, zk, grid%phb(i,1,j)/g, nl_in )

!  compute the perturbation mass and the full mass

    grid%MU_1(i,j) = pd_surf-grid%p_top - grid%MUB(i,j)
    grid%MU_2(i,j) = grid%MU_1(i,j)
    grid%MU0(i,j) = grid%MU_1(i,j) + grid%MUB(i,j)

! given the dry pressure and coordinate system, interp the potential
! temperature and qv

    do k=1,kde-1

#if  !( HYBRID_COORD==1 )
      p_level = grid%znu(k)*(pd_surf - grid%p_top) + grid%p_top
#elif ( HYBRID_COORD==1 )
      p_level = grid%c3h(k)*(pd_surf - grid%p_top) + grid%c4h(k) + grid%p_top
#endif

      moist(i,k,j,P_QV) = interp_0( qv, pd_in, p_level, nl_in )
      grid%t_1(i,k,j)          = interp_0( theta, pd_in, p_level, nl_in ) - t0
      grid%t_2(i,k,j)          = grid%t_1(i,k,j)
      

    enddo

!  integrate the hydrostatic equation (from the RHS of the bigstep
!  vertical momentum equation) down from the top to get grid%p.
!  first from the top of the model to the top pressure

    kk = kte-1  ! top level
    k=kk+1

    qvf1 = 0.5*(moist(i,kk,j,P_QV)+moist(i,kk,j,P_QV))
    qvf2 = 1./(1.+qvf1)
    qvf1 = qvf1*qvf2

    grid%p(i,kk,j) = - 0.5*(grid%Mu_1(i,j)+qvf1*grid%Mub(i,j))/grid%rdnw(kk)/qvf2
    qvf = 1. + rvovrd*moist(i,kk,j,P_QV)
    grid%alt(i,kk,j) = (r_d/p1000mb)*(grid%t_1(i,kk,j)+t0)*qvf* &
                (((grid%p(i,kk,j)+grid%pb(i,kk,j))/p1000mb)**cvpm)
    grid%al(i,kk,j) = grid%alt(i,kk,j) - grid%alb(i,kk,j)

!  down the column

    do kk=kte-2,1,-1
      k = kk + 1
      qvf1 = 0.5*(moist(i,kk,j,P_QV)+moist(i,kk+1,j,P_QV))
      qvf2 = 1./(1.+qvf1)
      qvf1 = qvf1*qvf2
      grid%p(i,kk,j) = grid%p(i,kk+1,j) - (grid%Mu_1(i,j) + qvf1*grid%Mub(i,j))/qvf2/grid%rdn(kk+1)
      qvf = 1. + rvovrd*moist(i,kk,j,P_QV)
      grid%alt(i,kk,j) = (r_d/p1000mb)*(grid%t_1(i,kk,j)+t0)*qvf* &
                  (((grid%p(i,kk,j)+grid%pb(i,kk,j))/p1000mb)**cvpm)
      grid%al(i,kk,j) = grid%alt(i,kk,j) - grid%alb(i,kk,j)
    enddo

!  this is the hydrostatic equation used in the model after the
!  small timesteps.  In the model, grid%al (inverse density)
!  is computed from the geopotential.


    grid%ph_1(i,1,j) = 0.
    DO kk  = 2,kte
      k = kk-1
      grid%ph_1(i,kk,j) = grid%ph_1(i,kk-1,j) - (grid%dnw(kk-1))*(       &
                   (grid%mub(i,j)+grid%mu_1(i,j))*grid%al(i,kk-1,j)+ &
                    grid%mu_1(i,j)*grid%alb(i,kk-1,j)  )
                                                   
      grid%ph_2(i,kk,j) = grid%ph_1(i,kk,j) 
      grid%ph0(i,kk,j) = grid%ph_1(i,kk,j) + grid%phb(i,kk,j)
    ENDDO

    if((i==2) .and. (j==2)) then
     k=1
     write(6,*) ' grid%ph_1 k=1 calc ',grid%ph_1(2,k,2),&
                              grid%mu_1(2,2)+grid%mub(2,2),grid%mu_1(2,2), &
                              grid%alb(2,k,2),grid%rdnw(k)
     k=2
     write(6,*) ' grid%ph_1 k=2 calc ',grid%ph_1(2,k,2),&
                              grid%mu_1(2,2)+grid%mub(2,2),grid%mu_1(2,2), &
                              grid%alb(2,k,2)
    endif

  ENDDO
  ENDDO
#if 0
!===============

!  Test for resting atmosphere

  DO iter_loop = 1, 100
     DO J = jts, min(jde-1,jte)
        DO I = its, min(ide-1,ite)
            DO K = 2, kte-1
               z1 = (grid%phb(i,k+1,j)+grid%ph_1(i,k+1,j))/g
               z2 = (grid%phb(i,k  ,j)+grid%ph_1(i,k  ,j))/g
               z=(z1+z2)/2.
               IF ( z .LT. 10000 ) THEN
                  Nsq = 1.E-4
               ELSE
                  Nsq = 4.E-4
               END IF
               grid%t_1(i,k,j)=(grid%t_1(i,k-1,j)+t0) * EXP(Nsq / g * (z1-z2)) - t0
               grid%t_2(i,k,j)=grid%t_1(i,k,j)
               qvf = 1. + rvovrd*moist(i,k,j,P_QV)
               grid%alt(i,k,j) = (r_d/p1000mb)*(grid%t_1(i,k,j)+t0)*qvf* &
                                 (((grid%p(i,k,j)+grid%pb(i,k,j))/p1000mb)**cvpm)
               grid%al(i,k,j) = grid%alt(i,k,j) - grid%alb(i,k,j)
            ENDDO
      
            DO kk  = 2,kte
              k = kk - 1
              grid%ph_1(i,kk,j) = grid%ph_1(i,kk-1,j) - (grid%dnw(kk-1))*(       &
                           (grid%mub(i,j)+grid%mu_1(i,j))*grid%al(i,kk-1,j)+ &
                            grid%mu_1(i,j)*grid%alb(i,kk-1,j)  )
      
              grid%ph_2(i,kk,j) = grid%ph_1(i,kk,j)
              grid%ph0(i,kk,j) = grid%ph_1(i,kk,j) + grid%phb(i,kk,j)
            ENDDO
        ENDDO
     ENDDO
  END DO

!===============
#endif
   k=1
   write(6,*) ' grid%mu_1 from comp ', grid%mu_1(1,1)
   write(6,*) ' full state sounding from comp, ph, grid%p, grid%al, grid%t_1, qv '
   do k=1,kde-1
     write(6,'(i3,1x,5(1x,1pe10.3))') k, grid%ph_1(1,k,1)+grid%phb(1,k,1), &
                                      grid%p(1,k,1)+grid%pb(1,k,1), grid%alt(1,k,1), &
                                      grid%t_1(1,k,1)+t0, moist(1,k,1,P_QV)
   enddo

   write(6,*) ' pert state sounding from comp, grid%ph_1, pp, alp, grid%t_1, qv '
   do k=1,kde-1
     write(6,'(i3,1x,5(1x,1pe10.3))') k, grid%ph_1(1,k,1), &
                                      grid%p(1,k,1), grid%al(1,k,1), &
                                      grid%t_1(1,k,1), moist(1,k,1,P_QV)
   enddo

! interp v

  DO J = jts, jte
  DO I = its, min(ide-1,ite)

    IF (j == jds) THEN
      z_at_v = grid%phb(i,1,j)/g
    ELSE IF (j == jde) THEN
      z_at_v = grid%phb(i,1,j-1)/g
    ELSE
      z_at_v = 0.5*(grid%phb(i,1,j)+grid%phb(i,1,j-1))/g
    END IF

    p_surf = interp_0( p_in, zk, z_at_v, nl_in )

    DO K = 1, kte
      p_level = grid%znu(k)*(p_surf - grid%p_top) + grid%p_top
      grid%v_1(i,k,j) = interp_0( v, p_in, p_level, nl_in )
      grid%v_2(i,k,j) = grid%v_1(i,k,j)
    ENDDO

  ENDDO
  ENDDO

! interp u

  DO J = jts, min(jde-1,jte)
  DO I = its, ite

    IF (i == ids) THEN
      z_at_u = grid%phb(i,1,j)/g
    ELSE IF (i == ide) THEN
      z_at_u = grid%phb(i-1,1,j)/g
    ELSE
      z_at_u = 0.5*(grid%phb(i,1,j)+grid%phb(i-1,1,j))/g
    END IF

    p_surf = interp_0( p_in, zk, z_at_u, nl_in )

    DO K = 1, kte
#if  !( HYBRID_COORD==1 )
      p_level = grid%znu(k)*(p_surf - grid%p_top) + grid%p_top
#elif ( HYBRID_COORD==1 )
      p_level = grid%c3h(k)*(p_surf - grid%p_top) + grid%c4h(k) + grid%p_top
#endif
      grid%u_1(i,k,j) = interp_0( u, p_in, p_level, nl_in )
      grid%u_2(i,k,j) = grid%u_1(i,k,j)
    ENDDO

  ENDDO
  ENDDO

!  set w

  DO J = jts, min(jde-1,jte)
  DO K = kts, kte
  DO I = its, min(ide-1,ite)
    grid%w_1(i,k,j) = 0.
    grid%w_2(i,k,j) = 0.
  ENDDO
  ENDDO
  ENDDO

!  set a few more things

  DO J = jts, min(jde-1,jte)
  DO K = kts, kte-1
  DO I = its, min(ide-1,ite)
    grid%h_diabatic(i,k,j) = 0.
  ENDDO
  ENDDO
  ENDDO

  DO k=1,kte-1
    grid%t_base(k) = grid%t_1(1,k,1)
    grid%qv_base(k) = moist(1,k,1,P_QV)
    grid%u_base(k) = grid%u_1(1,k,1)
    grid%v_base(k) = grid%v_1(1,k,1)
    grid%z_base(k) = 0.5*(grid%phb(1,k,1)+grid%phb(1,k+1,1)+grid%ph_1(1,k,1)+grid%ph_1(1,k+1,1))/g
  ENDDO

  DO J = jts, min(jde-1,jte)
  DO I = its, min(ide-1,ite)
     thtmp   = grid%t_2(i,1,j)+t0
     ptmp    = grid%p(i,1,j)+grid%pb(i,1,j)
     temp(1) = thtmp * (ptmp/p1000mb)**rcp
     thtmp   = grid%t_2(i,2,j)+t0
     ptmp    = grid%p(i,2,j)+grid%pb(i,2,j)
     temp(2) = thtmp * (ptmp/p1000mb)**rcp
     thtmp   = grid%t_2(i,3,j)+t0
     ptmp    = grid%p(i,3,j)+grid%pb(i,3,j)
     temp(3) = thtmp * (ptmp/p1000mb)**rcp

     grid%tsk(I,J)=grid%cf1*temp(1)+grid%cf2*temp(2)+grid%cf3*temp(3)
     grid%tmn(I,J)=grid%tsk(I,J)-0.5
  ENDDO
  ENDDO

  RETURN

 END SUBROUTINE init_domain_rk

   SUBROUTINE init_module_initialize
   END SUBROUTINE init_module_initialize

!---------------------------------------------------------------------

!  test driver for get_sounding
!
!      implicit none
!      integer n
!      parameter(n = 1000)
!      real zk(n),p(n),theta(n),rho(n),u(n),v(n),qv(n),pd(n)
!      logical dry
!      integer nl,k
!
!      dry = .false.
!      dry = .true.
!      call get_sounding( zk, p, pd, theta, rho, u, v, qv, dry, n, nl )
!      write(6,*) ' input levels ',nl
!      write(6,*) ' sounding '
!      write(6,*) '  k  height(m)  press (Pa) pd(Pa) theta (K) den(kg/m^3)  u(m/s)     v(m/s)    qv(g/g) '
!      do k=1,nl
!        write(6,'(1x,i3,8(1x,1pe10.3))') k, zk(k), p(k), pd(k), theta(k), rho(k), u(k), v(k), qv(k)
!      enddo
!      end
!
!---------------------------------------------------------------------------

      subroutine get_sounding( zk, p, p_dry, theta, rho, &
                               u, v, qv, dry, nl_max, nl_in, base_state )
      implicit none

      integer nl_max, nl_in
      real zk(nl_max), p(nl_max), theta(nl_max), rho(nl_max), &
           u(nl_max), v(nl_max), qv(nl_max), p_dry(nl_max)
      logical dry
      logical base_state

      integer n, iz
      parameter(n=1000)
      logical debug
      parameter( debug = .true.) !bloss: output sounding by default

! input sounding data

      real p_surf, th_surf, qv_surf
      real pi_surf, pi(n)
      real h_input(n), th_input(n), qv_input(n), u_input(n), v_input(n)

! diagnostics

      real rho_surf, p_input(n), rho_input(n)
      real pm_input(n)  !  this are for full moist sounding

! local data

      real r
      parameter (r = r_d)
      integer k, it, nl
      real qvf, qvf1, dz

!  first, read the sounding

      call read_sounding( p_surf, th_surf, qv_surf, &
                          h_input, th_input, qv_input, u_input, v_input,n, nl, debug )

!        iz = 1
!        do k=2,nl
!          if(h_input(k) .lt. 12000.) iz = k
!        enddo
!        write(6,*) " tropopause ",iz,h_input(iz)
!        if(dry) then
!        write(6,*) ' nl is ',nl
!        do k=1,nl
!          th_input(k) = th_input(k)+10.+10*float(k)/nl
!        enddo
!        write(6,*) ' finished adjusting theta '
!        endif

!        do k=1,nl
!          u_input(k) = 2*u_input(k)
!        enddo
!
!      end if

      if(dry) then
       do k=1,nl
         qv_input(k) = 0.
       enddo
      endif

      if(debug) write(6,*) ' number of input levels = ',nl

        nl_in = nl
        if(nl_in .gt. nl_max ) then
          write(6,*) ' too many levels for input arrays ',nl_in,nl_max
          call wrf_error_fatal ( ' too many levels for input arrays ' )
        end if

!  compute diagnostics,
!  first, convert qv(g/kg) to qv(g/g)

      do k=1,nl
        qv_input(k) = 0.001*qv_input(k)
      enddo

      p_surf = 100.*p_surf  ! convert to pascals
      qvf = 1. + rvovrd*qv_input(1) 
      rho_surf = 1./((r/p1000mb)*th_surf*qvf*((p_surf/p1000mb)**cvpm))
      pi_surf = (p_surf/p1000mb)**(r/cp)

      if(debug) then
        write(6,*) ' surface density is ',rho_surf
        write(6,*) ' surface pi is      ',pi_surf
      end if


!  integrate moist sounding hydrostatically, starting from the
!  specified surface pressure
!  -> first, integrate from surface to lowest level

          qvf = 1. + rvovrd*qv_input(1) 
          qvf1 = 1. + qv_input(1)
          rho_input(1) = rho_surf
          dz = h_input(1)
          do it=1,10
            pm_input(1) = p_surf &
                    - 0.5*dz*(rho_surf+rho_input(1))*g*qvf1
            rho_input(1) = 1./((r/p1000mb)*th_input(1)*qvf*((pm_input(1)/p1000mb)**cvpm))
          enddo

! integrate up the column

          do k=2,nl
            rho_input(k) = rho_input(k-1)
            dz = h_input(k)-h_input(k-1)
            qvf1 = 0.5*(2.+(qv_input(k-1)+qv_input(k)))
            qvf = 1. + rvovrd*qv_input(k)   ! qv is in g/kg here
 
            do it=1,20
              pm_input(k) = pm_input(k-1) &
                      - 0.5*dz*(rho_input(k)+rho_input(k-1))*g*qvf1
              rho_input(k) = 1./((r/p1000mb)*th_input(k)*qvf*((pm_input(k)/p1000mb)**cvpm))
            enddo
          enddo

!  we have the moist sounding

!  next, compute the dry sounding using p at the highest level from the
!  moist sounding and integrating down.

        p_input(nl) = pm_input(nl)

          do k=nl-1,1,-1
            dz = h_input(k+1)-h_input(k)
            p_input(k) = p_input(k+1) + 0.5*dz*(rho_input(k)+rho_input(k+1))*g
          enddo

!      write(6,*) ' zeroing u input '

        do k=1,nl

          zk(k) = h_input(k)
          p(k) = pm_input(k)
          p_dry(k) = p_input(k)
          theta(k) = th_input(k)
          rho(k) = rho_input(k)
          u(k) = u_input(k)
!          u(k) = 0.
          v(k) = v_input(k)
          qv(k) = qv_input(k)

        enddo

     if(debug) then
      write(6,*) ' sounding '
      write(6,*) '  k  height(m)  press (Pa) pd(Pa) theta (K) den(kg/m^3)  u(m/s)     v(m/s)    qv(g/g) '
      do k=1,nl
        write(6,'(1x,i3,8(1x,1pe10.3))') k, zk(k), p(k), p_dry(k), theta(k), rho(k), u(k), v(k), qv(k)
      enddo

     end if

      end subroutine get_sounding

!-------------------------------------------------------

      subroutine read_sounding( ps,ts,qvs,h,th,qv,u,v,n,nl,debug )
      implicit none
      integer n,nl
      real ps,ts,qvs,h(n),th(n),qv(n),u(n),v(n)
      logical end_of_file
      logical debug

      integer k

      open(unit=10,file='input_sounding',form='formatted',status='old')
      rewind(10)
      read(10,*) ps, ts, qvs
      if(debug) then
        write(6,*) ' input sounding surface parameters '
        write(6,*) ' surface pressure (mb) ',ps
        write(6,*) ' surface pot. temp (K) ',ts
        write(6,*) ' surface mixing ratio (g/kg) ',qvs
      end if

      end_of_file = .false.
      k = 0

      do while (.not. end_of_file)

        read(10,*,end=100) h(k+1), th(k+1), qv(k+1), u(k+1), v(k+1)
        k = k+1
        if(debug) write(6,'(1x,i3,5(1x,e10.3))') k, h(k), th(k), qv(k), u(k), v(k)
        go to 110
 100    end_of_file = .true.
 110    continue
      enddo

      nl = k

      close(unit=10,status = 'keep')

      end subroutine read_sounding

END MODULE module_initialize_ideal
