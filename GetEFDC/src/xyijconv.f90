MODULE XYIJCONV
! ** AUTHOR: DH CHUNG

USE GLOBALVARS  
USE INFOMOD

IMPLICIT NONE

CONTAINS

 SUBROUTINE XY2IJ(CEL)
  TYPE(CELL),INTENT(INOUT),OPTIONAL::CEL
  INTEGER(4)::N,NPMAX
  
  IF (PRESENT(CEL)) THEN
    NPMAX = SIZE(CEL%XCEL)
    DO N=1,NPMAX 
      CALL CONTAINERIJ(N,CEL%XCEL(N),CEL%YCEL(N),CEL%ICEL(N),CEL%JCEL(N))
    ENDDO
  ELSE
    CALL AREA_CENTRD
    DO N=1,NLOC
      CALL CONTAINER(N)
    ENDDO
 ENDIF 
 END SUBROUTINE

 SUBROUTINE CONTAINER(NCEL)   
  !OUTPUT: ICEL(NCEL),JCEL(NCEL)
  INTEGER(4),INTENT(IN)   :: NCEL
  INTEGER(4)::LMILOC(1),L,I,J,ILN,JLN
  INTEGER(4)::I1,I2,J1,J2
  REAL(8) ::RADLA(LA)
  
  !FOR THE FIRST CALL                     
  RADLA(2:LA) = SQRT((XCEL(NCEL)-XCOR(2:LA,5))**2+(YCEL(NCEL)-YCOR(2:LA,5))**2) 
  LMILOC = MINLOC(RADLA(2:LA))
  ILN = IL(LMILOC(1)+1)    !I OF THE NEAREST CELL FOR DRIFTER
  JLN = JL(LMILOC(1)+1)    !J OF THE NEAREST CELL FOR DRIFTER     

  !DETERMINE THE CELL CONTAINING THE DRIFTER WITHIN 9 CELLS: LLA(NCEL)
  I1 = MAX(1,ILN-1)
  I2 = MIN(ILN+1,ICM)
  J1 = MAX(1,JLN-1)
  J2 = MIN(JLN+1,JCM)
  LOOP:DO J=J1,J2
    DO I=I1,I2
      L = LIJ(I,J)
      IF (L<2) CYCLE
      IF (INSIDECELL(L,XCEL(NCEL),YCEL(NCEL))) THEN
        ICEL(NCEL) = I
        JCEL(NCEL) = J
        RETURN
      ENDIF
    ENDDO
  ENDDO LOOP
  PRINT*,'THIS CELL IS OUTSIDE THE DOMAIN:',NCEL
  STOP
 END SUBROUTINE

 SUBROUTINE AREACAL(XC,YC,AREA)   
  !AREA CALCULATION OF A POLYGON
  !WITH GIVEN VEXTICES (XC,YC)
  REAL(8),INTENT(IN) ::XC(:),YC(:)
  REAL(8),INTENT(OUT)::AREA
  REAL(8)::XVEC(2),YVEC(2)
  INTEGER(4)::NPOL,K
  NPOL = SIZE(XC)
  AREA = 0
  XVEC(1)=XC(2)-XC(1)
  YVEC(1)=YC(2)-YC(1)
  DO K=3,NPOL
    XVEC(2) = XC(K)-XC(1)
    YVEC(2) = YC(K)-YC(1)
    AREA = AREA+0.5*ABS( XVEC(1)*YVEC(2)-XVEC(2)*YVEC(1))
    XVEC(1)=XVEC(2)
    YVEC(1)=YVEC(2)
  ENDDO
 END SUBROUTINE

 FUNCTION INSIDECELL(L,XM,YM) RESULT(INSIDE)   
  LOGICAL(4)::INSIDE
  INTEGER(4),INTENT(IN)::L
  REAL(8) ,INTENT(IN)::XM,YM
  REAL(8) ::XC(6),YC(6),AREA2
  XC(1) = XM 
  YC(1) = YM 
  XC(2:5)=XCOR(L,1:4)
  YC(2:5)=YCOR(L,1:4)
  XC(6) = XC(2)
  YC(6) = YC(2)
  CALL AREACAL(XC,YC,AREA2)
  IF (ABS(AREA2-AREA(L)<=1D-6)) THEN
    INSIDE=.TRUE.
  ELSE 
    INSIDE=.FALSE.
  ENDIF
 END FUNCTION

 SUBROUTINE AREA_CENTRD(SCA)
  INTEGER(4),INTENT(IN),OPTIONAL::SCA
  INTEGER(4)::I,J,K
  REAL(8)::XC(4),YC(4),AREA2
  
  PRINT *,'*** READING CORNERS.INP'
  OPEN(UCOR,FILE=CORNFILE,ACTION='READ')
  CALL SKIPCOM(UCOR, '*')
  XCOR = 0
  YCOR = 0
  AREA = 0
  DO WHILE(1)
     READ(UCOR,*,END=100,ERR=998) I,J,(XCOR(LIJ(I,J),K),YCOR(LIJ(I,J),K),K=1,4)
     XC(1:4) = XCOR(LIJ(I,J),1:4)
     YC(1:4) = YCOR(LIJ(I,J),1:4)
     IF (.NOT.PRESENT(SCA)) THEN
       CALL AREACAL(XC,YC,AREA2)
       AREA(LIJ(I,J)) = AREA2
     ENDIF
     ! *** STORE THE CELL CENTROID IN INDEX=5
     XCOR(LIJ(I,J),5) = 0.25*SUM(XC)        
     YCOR(LIJ(I,J),5) = 0.25*SUM(YC)
  ENDDO
  100 CLOSE(UCOR)
  RETURN
  998 STOP 'CORNERS.INP READING ERROR!'
 END SUBROUTINE

 SUBROUTINE CONTAINERIJ(NCEL,XCLL,YCLL,ICLL,JCLL)   
  INTEGER(4),INTENT(IN ):: NCEL
  REAL(8),   INTENT(IN ):: XCLL,YCLL
  INTEGER(4),INTENT(OUT):: ICLL,JCLL
  INTEGER(4)::LMILOC(1),L,I,J,ILN,JLN
  INTEGER(4)::I1,I2,J1,J2
  REAL(8) ::RADLA(LA)
  CHARACTER(200)::STR,SSTR*10
  
  !FOR THE FIRST CALL                     
  RADLA(2:LA) = SQRT((XCLL-XCOR(2:LA,5))**2+(YCLL-YCOR(2:LA,5))**2) 
  LMILOC = MINLOC(RADLA(2:LA))
  ILN = IL(LMILOC(1)+1)    !I OF THE NEAREST CELL FOR DRIFTER
  JLN = JL(LMILOC(1)+1)    !J OF THE NEAREST CELL FOR DRIFTER     

  !DETERMINE THE CELL CONTAINING THE DRIFTER WITHIN 9 CELLS: LLA(NCEL)
  I1 = MAX(1,ILN-1)
  I2 = MIN(ILN+1,ICM)
  J1 = MAX(1,JLN-1)
  J2 = MIN(JLN+1,JCM)
  LOOP:DO J=J1,J2
    DO I=I1,I2
      L = LIJ(I,J)
      IF (L<2) CYCLE
      IF (INSIDECELL(L,XCLL,YCLL)) THEN
        ICLL = I
        JCLL = J
        RETURN
      ENDIF
    ENDDO
  ENDDO LOOP
  WRITE(SSTR,'(I5)') NCEL
  STR='THIS CELL IS OUTSIDE THE DOMAIN: '//TRIM(SSTR)
  PRINT*,STR
  STOP
 END SUBROUTINE
 
END MODULE