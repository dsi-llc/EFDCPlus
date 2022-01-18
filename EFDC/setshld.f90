! ----------------------------------------------------------------------
!   This file is a part of EFDC+
!   Website:  https://eemodelingsystem.com/
!   Repository: https://github.com/dsi-llc/EFDC_Plus.git
! ----------------------------------------------------------------------
! Copyright 2021-2022 DSI, LLC
! Distributed under the GNU GPLv2 License.
! ----------------------------------------------------------------------
SUBROUTINE SETSHLD(TSC,THETA,D,SSG,DSR,USC)

  ! CHANGE RECORD

  ! **  NONCOHESIVE SEDIMENT SETTLING AND SHIELDS CRITERIA
  ! **  USING VAN RIJN'S EQUATIONS

  IMPLICIT NONE

  REAL :: TSC,THETA,D,SSG,DSR,USC,VISC,GP,TMP,GPD

  IF( D <= 1E-8 )THEN
    TSC = 0.0000055
    USC = 0.0023
    RETURN
  ENDIF

  VISC = 1.D-6
  GP = (SSG-1.)*9.82
  TMP = GP/(VISC*VISC)
  DSR = D*(TMP**0.333333)
  GPD = GP*D

  ! **  SHIELDS
  IF(DSR <= 4.0 )THEN
    THETA = 0.24/DSR
  ENDIF
  IF(DSR > 4.0 .AND. DSR <= 10.0 )THEN
    THETA = 0.14/(DSR**0.64)
  ENDIF
  IF(DSR > 10.0 .AND. DSR <= 20.0 )THEN
    THETA = 0.04/(DSR**0.1)
  ENDIF
  IF(DSR > 20.0 .AND. DSR <= 150.0 )THEN
    THETA = 0.013*(DSR**0.29)
  ENDIF
  IF(DSR > 150.0 )THEN
    THETA = 0.055
  ENDIF
  TSC=GPD*THETA
  USC=SQRT(TSC)

END SUBROUTINE

