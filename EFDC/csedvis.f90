! ----------------------------------------------------------------------
!   This file is a part of EFDC+
!   Website:  https://eemodelingsystem.com/
!   Repository: https://github.com/dsi-llc/EFDC_Plus.git
! ----------------------------------------------------------------------
! Copyright 2021-2022 DSI, LLC
! Distributed under the GNU GPLv2 License.
! ----------------------------------------------------------------------
FUNCTION CSEDVIS(SED)

  ! CHANGE RECORD
  !
  !
  ! **  CALCULATES KINEMATIC VISCOSITY OF HIGH CONCENTRATION COHESIVE
  ! **  SEDIMENT-WATER MIXTURE BASED ON
  ! **
  ! **  MEHTA, A. J., AND F.JIANG, 1990: SOME OBSERVATIONS ON BOTTOM
  ! **  MUD MOTION DUE TO WAVES. COASTAL AND OCEANOGRAPHIC ENGINEERING
  ! **  DEPARTMENT, UNIVERSITY OF FLORIDA, GAINESVILLE, FL32661

  IMPLICIT NONE
  REAL :: CSEDVIS,SED,WTL,WTH,VISL,VISH,VISR

  IF( SED <= 25667.) VISR=0.116883D-3*SED
  IF( SED >= 36667.) VISR=1.52646D-6*SED+3.125
  IF( SED > 25667.0 .AND. SED < 36667.0 )THEN
    WTL=(36667.-SED)/11000.
    WTH=(SED-25667.)/11000.
    VISL=0.116883D-3*25667
    VISH=1.52646D-6*36667.+3.125
    VISR=WTL*VISL+WTH*VISH
  ENDIF
  CSEDVIS=1.D-6*(10.**VISR)

END FUNCTION

