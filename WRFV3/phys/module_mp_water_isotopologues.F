MODULE module_mp_water_isotopologues

  implicit none

  !bloss: Constants for computing isotope fractionation
  ! NOTE iso_index=18, H2O16
  ! NOTE iso_index=19, HDO16
  ! NOTE iso_index=20, H2O18
  ! NOTE iso_index=17, H2O17 (!!NOT IMPLEMENTED YET!!)
  !
  !                 DEUTERIUM         O18
  REAL, DIMENSION(18:20), PARAMETER, PRIVATE :: &
       calI1 = (/  0.,   16288.,      0.       /), & ! coefs in \alpha_I computation
       calI2 = (/  0.,   0.,          11.839    /), &
       calI3=  (/  0.,  -0.0934,     -0.028224 /), &
       calW1 = (/  0.,   24884.,      1137.       /), & ! coefs in \alpha_W computation
       calW2=  (/  0.,  -76.248,     -0.4156   /), &
       calW3=  (/  0.,   0.052612,   -0.0020667/)
  REAL, DIMENSION(18:20), PARAMETER :: & ! Merlivat (1978), ratio of molecular diffusivities
       Drat_light_over_heavy =  (/     1.0000,  1./0.9755,     1./0.9723 /), &  ! D_v / D_v'
       Mrat_light_over_heavy =  (/     18./18.,    18./19.,      18./20. /)    ! M/M' where ' is the heavy isotope

  INTEGER, DIMENSION(1:3), PARAMETER :: &
       iso_index_ref = (/  18,  19,  20 /)         ! indices needed for alpha_* computations

  CHARACTER(LEN=3), DIMENSION(18:20), PARAMETER :: &
       iso_string = (/ 'H2O', 'HDO', 'O18' /)

  !bloss/wiso(2017-09): Add variables specifying a wind-speed-independent kinetic fractionation
  !   coefficient for isotopic surface fluxes (from Pfahl & Wernli, 2009, JGR, doi:10.1029/2009JD012054)
  REAL, PARAMETER :: kfac_surf_HDO = 0.9961, kfac_surf_O18 = 0.9925

!..Controls for isotope implementation (MOSTLY FOR TESTING)
!     can be set through MP_WISO namelist that is read in thompiso_init() in module_mp_thomiso.F
  LOGICAL :: fractionate = .true. ! if false, turns off isotopic fractionation in the microphysics
                                  !     and elsewhere in the model

  !iso_factor is a small number to make the contribution of isotopes to
  !  the mass negligible It is an inconvenience due to putting isotopes in
  !  microphysics.
  REAL     , PARAMETER ::            iso_factor=1.e-10
  !
CONTAINS 

  !****************************************************************
  !****************************************************************
  !bloss 061209
  !Add function that only computes equilibrium alpha for liquid.
  !  Coefficients are from Majoube (1971, Journal
  !  de Chimie Physique et Physico-Chimie Biologique, vol. 68,
  !  no. 10, pp. 1423-1436).
  REAL FUNCTION alfaW_equilibrium(Tk,iso_index)
    !----------------------------------------------------------------
    IMPLICIT NONE
    !----------------------------------------------------------------
    REAL, INTENT(IN   ) :: Tk
    INTEGER, INTENT(IN) :: iso_index !==19 for HDO, ==20 for H2O18

    alfaW_equilibrium = &
         exp( (calW1(iso_index) + Tk*(calW2(iso_index) + Tk*calW3(iso_index))) &
              /(Tk*Tk) )

  END FUNCTION alfaW_equilibrium

  !****************************************************************
  !****************************************************************
  !bloss 061209
  !Add function that only computes equilibrium alpha for ice.
  !  Coefficients for O18 are from Majoube (1970, Nature, vol. 226,
  !  p. 1242, 27 June 1970, doi: 10.1038/2261242a0).  Those for
  !  deuterium are from Merlivat & Nief (1967, Tellus, doi:
  !  10.1111/j.2153-3490.1967.tb01465.x) as presented in Jouzel (1986,
  !  Handbook of Environmental Isotope Geochemistry) with a couple
  !  of differences in the last decimal places.
  !   Merlivat & Nief: alfaI = exp(-0.0945 + 16289/T^2)
  !   Jouzel 1986: alfaI = exp(-0.0934 + 16288/T^2)

  REAL FUNCTION alfaI_equilibrium(Tk,iso_index)
    !----------------------------------------------------------------
    IMPLICIT NONE
    !----------------------------------------------------------------
    REAL, INTENT(IN   ) :: Tk
    INTEGER, INTENT(IN) :: iso_index !==19 for HDO, ==20 for H2O18

    alfaI_equilibrium = &
         exp( (calI1(iso_index) + Tk*(calI2(iso_index) + Tk*calI3(iso_index))) &
              /(Tk*Tk) )

  END FUNCTION alfaI_equilibrium

  !****************************************************************
  !****************************************************************
  REAL FUNCTION alfaK(alpha_equil, S_tilde, Vrat_light_over_heavy, iso_index)
    !bloss (061509, modified 2014-03-31): Note that alpha_k formula 
    !  is identical for liquid and ice.  Use a single function for both.
    !  The difference is in the equilibrium fractionation coefficient
    !  and the value of the saturation ratio S_tilde that are input.
    !  These will reflect whether the exchange occurs between vapor 
    !  and ice or vapor and liquid.
    !  Modification (in 2014): change formulation to remove dependence
    !  on material properties through the constant b in Gedzelman
    !  & Arnold (1994, doi: 10.1029/93JD03518) and the appendix of 
    !  Blossey et al (2010, doi: 10.1029/2010JD014554, eqn B26).  
    !  The current form is that of equation 11 in Jouzel & Merlivat 
    !  (1984, doi: 10.1029/JD089iD07p11749) where our S_tilde 
    !  corresponds to their Si, which is defined in their equation 13.
    !  In addition, we have included the ratio of the ventilation
    !  factors.
    !----------------------------------------------------------------
    IMPLICIT NONE
    !----------------------------------------------------------------
    REAL, INTENT(IN   ) :: alpha_equil  ! equilibrium fractionation
    REAL, INTENT(IN   ) :: S_tilde  ! saturation ratio = rv*^drop/rv_ambient
                                    !  equivalent to Si (Jouzel & Merlivat, 1984, eqn 13).
    REAL, INTENT(IN   ) :: Vrat_light_over_heavy ! = V/V' where V and V' are
                                ! ventilation coefficients for the 
                                ! standard and heavy isotopes, respectively. 
    INTEGER, INTENT(IN) :: iso_index !==19 for HDO, ==20 for H2O18

    alfaK = S_tilde / (1. + alpha_equil*(S_tilde - 1.) &
                             *Drat_light_over_heavy(iso_index) &
                             *Vrat_light_over_heavy)

  END FUNCTION alfaK

  !****************************************************************
  !****************************************************************
  REAL FUNCTION SurfaceFractionationCoefficient(type, windspeed, temperature, density, height, iso_index)
    !bloss (2018-12-06): Return the surface fractionation coefficient
    !   that represents the effect of differing molecular
    !   diffusivities of the heavy isotopologues on the surface
    !   transfer coefficient for moisture.  Three options are
    !   available:
    !     - Merlivat & Jouzel (1979, JGR, https://doi.org/10.1029/JC084iC08p05029 ): wind-speed-dependent
    !     - Pfahl & Wernli (2009, JGR, https://doi.org/10.1029/JC084iC08p05029 ): wind-speed-independent
    !     - 
    !----------------------------------------------------------------
    IMPLICIT NONE
    !----------------------------------------------------------------
    CHARACTER(LEN=*), INTENT(IN) :: type ! 'Merlivat', 'PfahlWernli', 'Schoenemann', 'Fairall'
    REAL, INTENT(IN   ) :: windspeed  ! wind speed in m/s
    REAL, INTENT(IN   ) :: temperature ! absolute temperature in K
    REAL, INTENT(IN   ) :: density ! density in kg/m3
    REAL, INTENT(IN   ) :: height ! height of lowest level in m
    INTEGER, INTENT(IN) :: iso_index !==19 for HDO, ==20 for H2O18

    select case (type(1:4))
      case ('Merl')
        SurfaceFractionationCoefficient = &
             MerlivatAlphaKinetic(windspeed,density,height,iso_index)
      case ('Pfah')
        select case(iso_index)
        case (18)
          SurfaceFractionationCoefficient = 1.0000 ! H2O16
        case (19)
          SurfaceFractionationCoefficient = 0.9961 ! HDO
        case (20)
          SurfaceFractionationCoefficient = 0.9925 ! H2O18
        case default
          write(*,*) 'Bad value for iso_index in SurfaceFractionationCoefficient'
          STOP 'in module_mp_water_isotopologues.F'
        end select
            
      case ('Scho')
        write(*,*) 'Fairall surface fractionation not yet coded, stopping...'
        STOP 'in module_mp_water_isotopologues.F'
!!$        alpha_diff_18 = 1.0096
!!$        alpha_diff_2 = 1. + 
!!$        select case(iso_index)
!!$        case (18)
!!$          SurfaceFractionationCoefficient = 1.0000 ! H2O16
!!$        case (19)
!!$          SurfaceFractionationCoefficient = 0.9961 ! HDO
!!$        case (20)
!!$          SurfaceFractionationCoefficient = 1./1.0096 ! H2O18 -- based on Luz & Barkan (2010)
!!$        case default
!!$          write(*,*) 'Bad value for iso_index in SurfaceFractionationCoefficient'
!!$          STOP 'in module_mp_water_isotopologues.F'
!!$        end select
            
      case ('Fair')
        write(*,*) 'Fairall surface fractionation not yet coded, stopping...'
        STOP 'in module_mp_water_isotopologues.F'

    case default
      write(*,*) TRIM(type), ' surface fractionation scheme not yet coded, stopping...'
      STOP 'in module_mp_water_isotopologues.F'
    end select

  END FUNCTION SurfaceFractionationCoefficient

  real function MerlivatAlphaKinetic(windspeed, density, zbot, iso_index)

    REAL, INTENT(IN   ) :: windspeed  ! wind speed in m/s
    REAL, INTENT(IN   ) :: density ! density in kg/m3
    REAL, INTENT(IN   ) :: zbot  ! height of bottom atmospheric level in m
    INTEGER, INTENT(IN) :: iso_index !==19 for HDO, ==20 for H2O18

    ! Parameters for Merlivat-Jouzel parameterization,
    !   taken from iCAM: models/csm_share/shr/water_isotopes.F90
    real, parameter :: difair = 2.36e-5 ! molecular diffusivity of air
    real, parameter :: muair  = 1.7e-5  ! dynamic viscosity of air
                                               ! about 17 degC, 1.73 at STP (Salby)
    real, parameter :: gravit = 9.80616    ! gravity 
    real, parameter :: karman = 0.4        ! Von Karman constant
    real, parameter :: umin  =  0.5 ! minimum wind speed (m/s)
    real, parameter :: recrit   = 1.0            ! critical raynolds number for kmol

    real :: z0                 ! roughness length (constant in cam 9.5e-5)
    real :: ustar              ! friction velocity, m/s
    real :: reno               ! surface reynolds number
    real :: tmr                ! ratio of turbulen to molecular resistance
    real :: enn		! diffusive power
    real :: sc                 ! Schmidt number (Prandtl number)
    real :: vmu                ! kinematic viscocity of air
    real :: difn               ! ratio of difusivities to the power of n
    real :: difrmj		! isotopic diffusion with substitutions
    real :: kmol               ! Merlivals k_mol
    real    :: vmag   ! surface wind magnitude   (m/s)
    real    :: rdn    ! sqrt of neutral exchange coeff (momentum) 
    real    :: cdn    ! function: neutral drag coeff at 10m
    real    :: Umps   ! windspeed input to drag coefficient computation
    cdn(Umps)  =   0.0027 / Umps + 0.000142 + 0.0000764 * Umps


        ! From iCAM: models/csm_share/shr/water_isotopes.F90
        difrmj = 1./Drat_light_over_heavy(iso_index)
!
        ! friction velocity (ustar) computation taken from
        !    iCAM: models/csm_share/shr/shr_flux_mod.F90
        vmag   = max(umin, windspeed )
        rdn    = sqrt(cdn(vmag))
        ustar = rdn * vmag

        ! compute Reynolds number
        z0 = (ustar**2.)/(81.1*gravit)  ! Charnock's equation
        vmu = muair / density             ! kinematic viscosity
        Sc  = vmu/difair
        reno = ustar*z0 / vmu       ! reynolds number
!
        if (reno < recrit) then        ! Smooth (Re < 0.13)
          enn = 2./3.
          tmr  = ( (1./karman)*log(ustar*zbot / (30. * vmu)) ) / (13.6 * Sc**(2./3.))
        else                           ! Rough  (Re > 2)
          enn = 1./2.
          tmr  = ( (1./karman)*log(zbot/z0) - 5.) / (7.3 * reno**(1./4.) * Sc**(1./2.))
        end if

        difn = (1./difrmj)**enn        ! use D/Di, not Di/D
        kmol = (difn - 1.) / (difn + tmr)

        MerlivatAlphaKinetic = 1. - kmol

  end function MerlivatAlphaKinetic

END MODULE module_mp_water_isotopologues
