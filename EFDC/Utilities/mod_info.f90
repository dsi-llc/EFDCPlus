! ----------------------------------------------------------------------
!   This file is a part of EFDC+
!   Website:  https://eemodelingsystem.com/
!   Repository: https://github.com/dsi-llc/EFDC_Plus.git
! ----------------------------------------------------------------------
! Copyright 2021-2022 DSI, LLC
! Distributed under the GNU GPLv2 License.
! ----------------------------------------------------------------------
MODULE INFOMOD
!Author: Dang Huu Chung

USE GLOBAL,ONLY:IK4
IMPLICIT NONE
CONTAINS

FUNCTION READSTR(UNIT) RESULT(STR)
  INTEGER(IK4),INTENT(IN) :: UNIT
  CHARACTER(200) :: STR
  INTEGER(IK4) :: ISTR,I
  DO WHILE (1)
    READ(UNIT,'(A)',ERR=1000,END=1010) STR
    STR = ADJUSTL(STR)
    ISTR = ICHAR(STR(1:1))
    I = 1
    DO WHILE (ISTR == 9) 
      I = I+1
      ISTR = ICHAR(STR(I:I))
    ENDDO
    SELECT CASE (ISTR)
    CASE (45,46,48:57)  !CHARACTER = -, ., 0:9
      BACKSPACE UNIT
      RETURN
    END SELECT
  ENDDO
  RETURN
  
1000 CALL STOPP('READ ERROR!')
1010 CALL STOPP('END OF FILE BEFORE EXPECTED!')
 
END FUNCTION

SUBROUTINE SKIPCOM(IUNIT,CC,IUOUT)
  INTEGER(IK4),  INTENT(IN) :: IUNIT    
  INTEGER(IK4),  INTENT(IN),OPTIONAL :: IUOUT
  CHARACTER(1),INTENT(IN) :: CC
  CHARACTER(250) :: LINE,COMM*1(4)
  INTEGER(IK4)   :: I,ISTR
  DATA COMM /'C','c','*','#'/
 
  DO WHILE(1)
    READ(IUNIT, '(A)', END=999) LINE      
    IF( PRESENT(IUOUT)) WRITE(IUOUT,'(A)') LINE
    LINE = ADJUSTL(LINE)
    ISTR = ICHAR(LINE(1:1))
    I = 1
    DO WHILE (ISTR == 9) 
      I = I+1
      ISTR = ICHAR(LINE(I:I))
    ENDDO
    IF( LINE(I:I) == CC .OR. ANY(COMM == LINE(I:I)) )THEN
      CYCLE
    ELSE
      BACKSPACE(IUNIT)
      EXIT
    ENDIF
  END DO
  999 RETURN
END SUBROUTINE
 
FUNCTION FINDSTR(STR,SS,NCOL) RESULT(COLM)
  CHARACTER(*)  :: STR,SS
  CHARACTER(10) :: SSN(NCOL)
  INTEGER(IK4)  :: M,COLM,NCOL,NL
  COLM=0
  READ(STR,*,end=100) (SSN(M),M=1,NCOL)
  100 continue
  DO M=1,NCOL
    SSN(M) = ADJUSTL(SSN(M))
    NL = INDEX(SSN(M),SS)
    IF( NL > 0 )THEN
      COLM = M
      RETURN
    ENDIF
  ENDDO
END FUNCTION

FUNCTION NUMCOL(STR) RESULT(NC)

  INTEGER(IK4) :: M,NC,NL
  CHARACTER(*) :: STR,STR1*200

  STR1 = ADJUSTL(STR)
  NL = LEN_TRIM(STR1)
  IF( NL == 0 )THEN
    NC=0
    RETURN
  ENDIF
  NC = 1
  DO M=2,NL
    IF( STR1(M:M) == '' .AND. STR1(M-1:M-1)/='' )THEN
      NC=NC+1
    ENDIF
  ENDDO
END FUNCTION
 
END MODULE
 

