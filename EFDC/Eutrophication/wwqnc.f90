! ----------------------------------------------------------------------
!   This file is a part of EFDC+
!   Website:  https://eemodelingsystem.com/
!   Repository: https://github.com/dsi-llc/EFDC_Plus.git
! ----------------------------------------------------------------------
! Copyright 2021-2022 DSI, LLC
! Distributed under the GNU GPLv2 License.
! ----------------------------------------------------------------------
SUBROUTINE WWQNC

  ! CHANGE RECORD
  ! WRITE INFORMATION OF NEGATIVE WQ STATE VARIABLES (UNIT IWQONC).

  USE GLOBAL
  Use Variables_WQ
  
  IMPLICIT NONE

  INTEGER     :: L, K, NW, LP, ND, IFLAG
  CHARACTER*5 :: WQVN(23)

  DATA WQVN/ &
      'BC ','BD ','BG ','RPOC','LPOC','DOC ','RPOP','LPOP','DOP ','PO4T','RPON','LPON', &
      'DON ','NH4 ','NO3 ','SU ','SA   ','COD  ','O2   ','TAM  ','FCB  ', 'CO2 ','MALG '/

  OPEN(1,FILE=OUTDIR//'WQ3DNC.LOG',STATUS='UNKNOWN',POSITION='APPEND')

  IFLAG = 0
  DO L=2,LA
    DO K=1,KC
      DO NW=1,NWQV
        IF( WQV(L,K,NW) < 0.0 )THEN
          WRITE(1,90) WQVN(NW),ITNWQ,L,IL(L),JL(L),K,WQV(L,K,NW)
          IFLAG = 1
        ENDIF
      ENDDO
    ENDDO
  ENDDO
  CLOSE(1)
  90 FORMAT(A5, I8, 4I5, E11.3)
  
  ! *** ZERO NEGATIVE CONCENTRATIONS
  IF( IWQNC > 1 .AND. IFLAG == 1 )THEN
    !$OMP PARALLEL DO PRIVATE(ND,K,LP,L,NW)
    DO ND=1,NDM  
      DO K=1,KC
        DO LP=1,LLWET(K,ND)
          L=LKWET(LP,K,ND) 
          DO NW = 1,NWQV
            IF( ISKINETICS(NW) > 0 )THEN
              IF( WQV(L,K,NW) < 0.0 ) WQV(L,K,NW) = 0.0
            ENDIF
          ENDDO
        ENDDO
      ENDDO
    ENDDO
    !$OMP END PARALLEL DO
  ENDIF
  
  RETURN
  
END

