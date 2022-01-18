! ----------------------------------------------------------------------
!   This file is a part of EFDC+
!   Website:  https://eemodelingsystem.com/
!   Repository: https://github.com/dsi-llc/EFDC_Plus.git
! ----------------------------------------------------------------------
! Copyright 2021-2022 DSI, LLC
! Distributed under the GNU GPLv2 License.
! ----------------------------------------------------------------------
FUNCTION FHYDCN(VOID,BMECH4,BMECH5,BMECH6,IBMECHK)

  ! **  FHYDCN IS HYDRAULIC CONDUCTIVITY DIVIDED BY 1+VOID RATIO
  !

  IMPLICIT NONE

  INTEGER :: IBMECHK
  REAL :: FHYDCN,VOID,BMECH4,BMECH5,BMECH6,TMP,FHYDCNLOG


  IF( BMECH4 > 0.0 )THEN
    TMP=(VOID-BMECH5)/BMECH6
    IF( IBMECHK == 0 )THEN
      FHYDCN=BMECH4*EXP(TMP)/(1.+VOID)
    ELSE
      FHYDCN=BMECH4*EXP(TMP)
    END IF
  ELSE
    FHYDCNLOG=0.00816448*(VOID**3)-0.232453*(VOID**2)+2.5759*VOID -28.581
    FHYDCN=EXP(FHYDCNLOG)
  ENDIF

END FUNCTION

