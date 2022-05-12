! ----------------------------------------------------------------------
!   This file is a part of EFDC+
!   Website:  https://eemodelingsystem.com/
!   Repository: https://github.com/dsi-llc/EFDC_Plus.git
! ----------------------------------------------------------------------
! Copyright 2021-2022 DSI, LLC
! Distributed under the GNU GPLv2 License.
! ----------------------------------------------------------------------
SUBROUTINE SEEK(TAG)
  
  USE GLOBAL,ONLY: IKV,CARDNO
  
  IMPLICIT NONE
  
  INTEGER :: I,J,K,L,M
  CHARACTER TAG*(*)
  CHARACTER*80 TEXT
  LOGICAL(4) :: OPN
  
  CARDNO = TAG
  INQUIRE(UNIT=7,OPENED=OPN) 
  
  L=LEN(TAG)
  DO I=1,L
    J=ICHAR(TAG(I:I))
    IF( 97 <= J .AND. J <= 122 )THEN
      TAG(I:I)=CHAR(J-32)
    ENDIF
  ENDDO  
  IF( OPN ) WRITE(7,'(A,A)')'SEEKING GROUP: ',TAG
  
  DO K=1,2
10  READ(1,'(A)',END=20)TEXT
    M=MAX(1,LEN_TRIM(TEXT))
    IF( OPN ) WRITE(7,'(A)')TEXT(1:M)
    DO WHILE(M > L .AND. TEXT(1:1) == '')
      TEXT(1:M-1)=TEXT(2:M)
      TEXT(M:M)=' '
      M=M-1
    ENDDO
    IF( M < L)GO TO 10
    DO I=1,M
      J=ICHAR(TEXT(I:I))
      IF( 97 <= J .AND. J <= 122 )THEN
        TEXT(I:I)=CHAR(J-32)
      ENDIF
    ENDDO
    IF( TEXT(1:L) /= TAG )     GO TO 10
    IF( TEXT(L+1:L+1) /= ' ' ) GO TO 10
  ENDDO
  !WRITE(8,'(A,A)') TAG,' FOUND.' 
  RETURN
 
  20 WRITE(*,'(A,A,A)')'GROUP: ',TAG,' NOT FOUND BEFORE END OF FILE'
  PAUSE
  
  CALL STOPP('.')

END

