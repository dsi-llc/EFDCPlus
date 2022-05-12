! ----------------------------------------------------------------------
!   This file is a part of EFDC+
!   Website:  https://eemodelingsystem.com/
!   Repository: https://github.com/dsi-llc/EFDC_Plus.git
! ----------------------------------------------------------------------
! Copyright 2021-2022 DSI, LLC
! Distributed under the GNU GPLv2 License.
! ----------------------------------------------------------------------
FUNCTION FSTRSE(VOID,BMECH1,BMECH2,BMECH3)

  ! **  FSTRSE IS WATER SPECIFIC WEIGHT NORMALIZED EFFECTIVE STRESS
  !
  IMPLICIT NONE
  
  REAL :: FSTRSE,VOID,BMECH1,BMECH2,BMECH3,TMP,FSTRSELOG

  IF( BMECH1 > 0.0 )THEN
    TMP=-(VOID-BMECH2)/BMECH3
    FSTRSE=BMECH1*EXP(TMP)
  ELSE
    FSTRSELOG=-0.0147351*(VOID**3)+0.311854*(VOID**2)-2.96371*VOID+7.34698
    FSTRSE=EXP(FSTRSELOG)
  ENDIF

END FUNCTION

