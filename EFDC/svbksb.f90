! ----------------------------------------------------------------------
!   This file is a part of EFDC+
!   Website:  https://eemodelingsystem.com/
!   Repository: https://github.com/dsi-llc/EFDC_Plus.git
! ----------------------------------------------------------------------
! Copyright 2021-2022 DSI, LLC
! Distributed under the GNU GPLv2 License.
! ----------------------------------------------------------------------
SUBROUTINE SVBKSB(U,W,V,M,N,MP,NP,B,X)

  ! **  FROM NUMERICAL RECIPES
  ! CHANGE RECORD
  !
  ! 2014-08           D H CHUNG        SET EXPLICIT PRECISIONS OF INTEGER & REAL
  IMPLICIT NONE

  INTEGER :: M,N,I,J,JJ
  INTEGER :: MP,NP
  
  REAL :: U(MP,NP),W(NP),V(NP,NP),B(MP),X(NP),S
  REAL,SAVE,ALLOCATABLE :: TMP(:)
  
  IF( .NOT. ALLOCATED(TMP) )THEN
    ALLOCATE(TMP(N))
    TMP=0.
  ENDIF
  
  DO 12 J=1,N
    S=0.
    IF( W(J) /= 0. )THEN
      DO 11 I=1,M
        S=S+U(I,J)*B(I)
      11 CONTINUE
      S=S/W(J)
    ENDIF
    TMP(J)=S
  12 CONTINUE

  DO 14 J=1,N
    S=0.
    DO 13 JJ=1,N
      S=S+V(J,JJ)*TMP(JJ)
    13   CONTINUE
    X(J)=S
  14 CONTINUE
  DEALLOCATE(TMP)

END SUBROUTINE

