! ----------------------------------------------------------------------
!   This file is a part of EFDC+
!   Website:  https://eemodelingsystem.com/
!   Repository: https://github.com/dsi-llc/EFDC_Plus.git
! ----------------------------------------------------------------------
! Copyright 2021-2022 DSI, LLC
! Distributed under the GNU GPLv2 License.
! ----------------------------------------------------------------------
FUNCTION FDSTRSE(VOID,BMECH1,BMECH2,BMECH3)

  ! **  FDSTRSE IS COMPRESSION LENGTH SCALE
  !        STRESS WITH RESPECT TO VOID RATIO
  !

  IMPLICIT NONE

  REAL :: FDSTRSE,VOID,BMECH1,BMECH2,BMECH3,TMP,FSTRSEL,DFSTRSEL

  IF( BMECH1 > 0.0 )THEN
    TMP=-(VOID-BMECH2)/BMECH3
    TMP=-(VOID-BMECH2)/BMECH3
    FDSTRSE=(BMECH1/BMECH3)*EXP(TMP)
  ELSE
    FSTRSEL=-0.0147351*(VOID**3)+0.311854*(VOID**2)-2.96371*VOID+7.34698
    DFSTRSEL=-0.0442053*(VOID**2)+0.623708*VOID-2.96371
    FDSTRSE=DFSTRSEL*EXP(FSTRSEL)
  END IF

END FUNCTION

