! ----------------------------------------------------------------------
!   This file is a part of EFDC+
!   Website:  https://eemodelingsystem.com/
!   Repository: https://github.com/dsi-llc/EFDC_Plus.git
! ----------------------------------------------------------------------
! Copyright 2021-2022 DSI, LLC
! Distributed under the GNU GPLv2 License.
! ----------------------------------------------------------------------
FUNCTION SETSTVEL(D,SSG)

  ! **  NONCOHEASIVE SEDIMENT SETTLING AND SHIELDS CRITERIA
  ! **  USING VAN RIJN'S EQUATIONS

  ! CHANGE RECORD

  IMPLICIT NONE

  REAL :: SETSTVEL,D,SSG,VISC,GP,GPD,SQGPD,RD,WSET,TMP

  VISC=1.D-6
  GP=(SSG-1.)*9.82
  GPD=GP*D
  SQGPD=SQRT(GPD)
  RD=SQGPD*D/VISC

  ! **  SETTLING VELOCITY

  IF( D < 1.0E-4 )THEN
    WSET=SQGPD*RD/18.
  ENDIF
  IF( D >= 1.0E-4 .AND. D < 1.E-3 )THEN
    TMP=SQRT(1.+0.01*RD*RD)-1.
    WSET=10.0*SQGPD*TMP/RD
  ENDIF
  IF( D >= 1.E-3 )THEN
    WSET=1.1*SQGPD
  ENDIF
  SETSTVEL=WSET

END FUNCTION

