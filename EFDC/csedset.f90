! ----------------------------------------------------------------------
!   This file is a part of EFDC+
!   Website:  https://eemodelingsystem.com/
!   Repository: https://github.com/dsi-llc/EFDC_Plus.git
! ----------------------------------------------------------------------
! Copyright 2021-2022 DSI, LLC
! Distributed under the GNU GPLv2 License.
! ----------------------------------------------------------------------
FUNCTION CSEDSET(SED,SHEAR,IOPT)

  ! *** CSEDSET CALCULATES CONCENTRATION DEPENDENT SETTLING VELOCITY OF
  ! *** COHESIVE SEDIMENT WITH UNITS OF M/S
  
  !----------------------------------------------------------------------C  
  ! CHANGE RECORD  
  ! DATE MODIFIED     BY               DESCRIPTION
  !----------------------------------------------------------------------!
  !    2015-06       CHRIS HALL        UPDATED THE SHRESTHA-ORLOB EQUATION
  !                  BILL MCANALLY/ASHISH MEHTA
  
  IMPLICIT NONE
  
  REAL, INTENT(IN)    :: SED,SHEAR
  INTEGER, INTENT(IN) :: IOPT
  REAL    :: CSEDSET,TMP,RNG,BG,WTMP,GG,CG,BD2,CON,VAL,TMPSED

  IF( SED <= 0.0001 )THEN
    CSEDSET = 0.0
    RETURN
  ENDIF

  ! **  IOPT=1  BASED ON
  ! **
  ! **  HWANG, K. N., AND A. J. MEHTA, 1989: FINE SEDIMENT ERODIBILITY
  ! **  IN LAKE OKEECHOBEE FLORIDA. COASTAL AND OCEANOGRAPHIC ENGINEERING
  ! **  DEPARTMENT, UNIVERSITY OF FLORIDA, GAINESVILLE, FL32661
  IF( IOPT == 1 )THEN
    TMPSED=SED/2000.
    TMP=LOG10(TMPSED)
    TMP=-16.*TMP*TMP/9.
    TMP=10.**TMP
    CSEDSET = 8.E-4*TMP
  ENDIF

  ! **  IOPT=2  BASED ON
  ! **
  ! **  SHRESTA, P. L., AND G. T. ORLOB, 1996: MULTIPHASE DISTRIBUTION
  ! **  OF COHESIVE SEDIMENTS AND HEAVY METALS IN ESTUARINE SYSTEMS,
  ! **  J. ENVIRONMENTAL ENGINEERING, 122, 730-740.
  IF( IOPT == 2 )THEN
    ! *** SHRESTHA-ORLOB EQUATION (DEPRECATED - 2015-06)
    !SED=(SED/2.65E-6)**(1/3)
    !BG=0.03*SHEAR**(-0.5)
    !WTMP=SED*BG
    !CSEDSET=WTMP/3600.
    
    ! *** MODIFIED (MEHTA) SHRESTHA-ORLOB EQUATION
    TMPSED  = 1.E-3*SED
    RNG     = 1.11075 + 0.0386*SHEAR
    BG      = EXP( -4.20706 + 0.1465*SHEAR )
    WTMP    = BG*TMPSED**RNG
    CSEDSET = WTMP/3600.
  ENDIF

  ! **  IOPT=3  BASED ON
  ! **
  ! **  ZIEGLER, C. K., AND B. S. NESBIT, 1995: LONG-TERM SIMULAITON
  ! **  OF FINE GRAIN SEDIMENT TRANSPORT IN LARGE RESERVOIR,
  ! **  J. HYDRAULIC ENGINEERING, 121, 773-781.
  IF( IOPT == 3 )THEN
    TMPSED  = 1.E-6*SED        ! *** CONVERT G/M^3 TO G/CM^3
    GG      = 1.E4*SHEAR       ! *** CONVERT FROM M^2/S^2 TO CM^2/S^2
    CG      = GG*TMPSED        ! *** G/CM/S^2 = G/CM^3 * CM^2/S^2
    CG      = MAX(CG,7.51E-6)
    BD2     = -0.4 - 0.25*LOG10(CG - 7.5E-6)
    CON     = 9.6E-4*(1.E-8)**BD2
    VAL     = CG**(-0.85-BD2)
    CSEDSET = 0.01*CON*VAL
  ENDIF
  
  ! **  IOPT=4  BASED ON SHEAR
  IF( IOPT == 4 )THEN
    GG      = 1.E4*SHEAR       ! *** CONVERT FROM M^2/S^2 TO CM^2/S^2
    TMPSED  = GG*SED
    CSEDSET = 8.E-5
    IF( TMPSED < 40.0  ) CSEDSET = 1.510E-5*(TMPSED**0.45)
    IF( TMPSED > 400.0 ) CSEDSET = 0.893E-6*(TMPSED**0.75)
  ENDIF

  ! **  IOPT=5  BASED ON HOUSATONIC RIVER
  ! **     HQ MODIFIED OPTION 5: CONVERT M/DAY TO M/SEC BY /86400
  !        INTERSECTION OF THE TWO FUNCTIONS IS AT 3.8 NOT 10.0
  IF( IOPT == 5 )THEN
    GG      = 1.E4*SHEAR       ! *** CONVERT FROM M^2/S^2 TO CM^2/S^2
    TMPSED  = GG*SED
    IF( TMPSED < 3.8 )THEN
      CSEDSET = (1.270*(TMPSED**0.79))/86400. ! 12/31/03 new WP regr
    ELSE
      CSEDSET = (3.024*(TMPSED**0.14))/86400. ! 12/31/03 Burban&Lick
    ENDIF
  ENDIF

  ! **  IOPT=6
  IF( IOPT == 6 )THEN
    GG      = 1.E4*SHEAR       ! *** CONVERT FROM M^2/S^2 TO CM^2/S^2
    TMPSED  = GG*SED
    IF( TMPSED <  100.0 )THEN
      CSEDSET = 2.*1.16E-5*(TMPSED**0.5)
    ELSE
      CSEDSET = 2.*1.84E-5*(TMPSED**0.4)
    ENDIF
  ENDIF

  ! **  IOPT=7  BASED ON
  IF( IOPT == 7 )THEN
    TMPSED  = SHEAR*SED
    CSEDSET = 0.0052*(TMPSED**0.470138)
  ENDIF
  
  ! ** MODIFIED SHRESTHA (CHRISTOPHER HALL JULY 9, 2015)
  IF( IOPT == 8 )THEN
    TMPSED = 1.E-3*SED        ! *** CONVERT G/M^3 TO G/L
    IF( SHEAR > 0.1 )THEN
        BG=0.06/SQRT(SHEAR)
    ELSE
        BG=0.1
    ENDIF
    CSEDSET = BG*(TMPSED/2650)**(1./3.)
  ENDIF

  RETURN
END

