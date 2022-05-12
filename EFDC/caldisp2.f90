! ----------------------------------------------------------------------
!   This file is a part of EFDC+
!   Website:  https://eemodelingsystem.com/
!   Repository: https://github.com/dsi-llc/EFDC_Plus.git
! ----------------------------------------------------------------------
! Copyright 2021-2022 DSI, LLC
! Distributed under the GNU GPLv2 License.
! ----------------------------------------------------------------------
SUBROUTINE CALDISP2

  ! CHANGE RECORD

  USE GLOBAL
  Use Variables_MPI
  
  IMPLICIT NONE                                                                                                          
  INTEGER :: K,KK,KT,L,LN                                                                                                  
  REAL :: CLTMP,CTMP,AMCPT,AMSPT,UAVG,VAVG,CUTMP,CMTMP                                                                     
  REAL :: CCUU,CCVV,CCUV,CCVU                                                                                              

  REAL,SAVE,ALLOCATABLE,DIMENSION(:) :: UP
  REAL,SAVE,ALLOCATABLE,DIMENSION(:) :: VP
  REAL,SAVE,ALLOCATABLE,DIMENSION(:) :: CCUTMP
  REAL,SAVE,ALLOCATABLE,DIMENSION(:) :: CCVTMP
  REAL,SAVE,ALLOCATABLE,DIMENSION(:) :: CRHS
  REAL,SAVE,ALLOCATABLE,DIMENSION(:) :: CSOL
  REAL,SAVE,ALLOCATABLE,DIMENSION(:) :: WTMP
  REAL,SAVE,ALLOCATABLE,DIMENSION(:,:) :: CDISP
  REAL,SAVE,ALLOCATABLE,DIMENSION(:,:) :: CDISPT
  REAL,SAVE,ALLOCATABLE,DIMENSION(:,:) :: CDISPI
  REAL,SAVE,ALLOCATABLE,DIMENSION(:,:) :: CCTMP
  REAL,SAVE,ALLOCATABLE,DIMENSION(:,:) :: VVTMP
  REAL,SAVE,ALLOCATABLE,DIMENSION(:,:) :: SVAL

  ! *** DSI BEGIN BLOCK
  IF( .NOT. ALLOCATED(UP) )THEN
    ALLOCATE(UP(KCM))
    ALLOCATE(VP(KCM))
    ALLOCATE(CCUTMP(KCM))
    ALLOCATE(CCVTMP(KCM))
    ALLOCATE(CRHS(MGM))
    ALLOCATE(CSOL(MGM))
    ALLOCATE(WTMP(MGM))
    ALLOCATE(CDISP(MGM,MGM))
    ALLOCATE(CDISPT(KCM,KCM))
    ALLOCATE(CDISPI(KCM,KCM))
    ALLOCATE(CCTMP(KCM,KCM))
    ALLOCATE(VVTMP(MGM,MGM))
    ALLOCATE(SVAL(KCM,LCM))

    ! *** ZERO LOCAL ARRAYS
    UP=0.0
    VP=0.0
    CCUTMP=0.0
    CCVTMP=0.0
    CRHS=0.0
    CSOL=0.0
    WTMP=0.0
    CDISP=0.0
    CDISPT=0.0
    CDISPI=0.0
    CCTMP=0.0
    VVTMP=0.0
    SVAL=0.0
  ENDIF
  ! *** DSI END BLOCK
  !
  DELT=DT

  ! **  INITIALIZE ON FIRST CALL
  IF( N == NDISP )THEN
  
    DO L=1,LC
      DO KK=1,KC
        DO K=1,KC
          BDISP(K,KK,L)=0.
        ENDDO
      ENDDO
    ENDDO
    DO L=1,LC
      DO K=1,KC
        BDISP(K,K,L)=1.
        FUDISP(K,L)=0.
        FVDISP(K,L)=0.
      ENDDO
    ENDDO
    DO L=1,LC
      DXXTCA(L)=0.
      DXYTCA(L)=0.
      DYXTCA(L)=0.
      DYYTCA(L)=0.
    ENDDO
  ENDIF

  ! **  CALCULATE VERTICAL DIFFUSION MATRIX AND INVERSE AND ACCUMULATE
  ! **  DATA FOR DISPERSION CALCULATION
  DO L=2,LA
    IF( LCT(L) == 5 .AND. SPB(L) /= 0. )THEN
      LN=LNC(L)
      DO K=1,KC
        UP(K)=0.5*(U(L,K)+U(LEC(L),K))
        VP(K)=0.5*(V(L,K)+V(LN,K))
      ENDDO
      UAVG=0.
      VAVG=0.
      DO K=1,KC
        UAVG=UAVG+DZC(L,K)*UP(K)
        VAVG=VAVG+DZC(L,K)*VP(K)
      ENDDO
      DO K=1,KC
        UP(K)=UP(K)-UAVG
        VP(K)=VP(K)-VAVG
      ENDDO
      DO KK=1,KC
        DO K=1,KC
          CDISP(K,KK)=0.
        ENDDO
      ENDDO
      CUTMP=-DELT*CDZKK(L,KSZ(L))*AB(L,KSZ(L))*HPI(L)
      CMTMP=1.-CUTMP
      CDISP(1,1)=CMTMP*DZC(L,KSZ(L))
      CDISP(1,2)=CUTMP*DZC(L,KSZ(L))
      DO K=2,KS
        IF( K < KSZ(L) )CYCLE
        CLTMP=-DELT*CDZKMK(L,K)*AB(L,K-1)*HPI(L)
        CUTMP=-DELT*CDZKK(L,K)*AB(L,K)*HPI(L)
        CMTMP=1.-CLTMP-CUTMP
        CDISP(K,K-1)=CLTMP*DZC(L,K)
        CDISP(K,K)=CMTMP*DZC(L,K)
        CDISP(K,K+1)=CUTMP*DZC(L,K)
      ENDDO
      CLTMP=-DELT*CDZKMK(L,KC)*AB(L,KS)*HPI(L)
      CMTMP=1.-CLTMP
      CDISP(KC,KS)=CLTMP*DZC(L,KC)
      CDISP(KC,KC)=CMTMP*DZC(L,KC)
      CALL SVDCMP(CDISP,KC,KC,MGM,MGM,WTMP,VVTMP)
      DO KK=1,KC
        DO K=1,KC
          CDISPT(K,KK)=CDISP(KK,K)
        ENDDO
      ENDDO
      DO KK=1,KC
        DO K=1,KC
          CDISPT(K,KK)=CDISPT(K,KK)/WTMP(K)
        ENDDO
      ENDDO
      DO KK=1,KC
        DO K=1,KC
          CTMP=0.
          DO KT=1,KC
            CTMP=CTMP+VVTMP(K,KT)*CDISPT(KT,KK)
          ENDDO
          CDISPI(K,KK)=CTMP
        ENDDO
      ENDDO
      DO KK=1,KC
        DO K=1,KC
          CDISPI(K,KK)=CDISPI(K,KK)*DZC(L,K)
        ENDDO
      ENDDO
      DO KK=1,KC
        DO K=1,KC
          CTMP=0.
          DO KT=1,KC
            CTMP=CTMP+CDISPI(K,KT)*BDISP(KT,KK,L)
          ENDDO
          CCTMP(K,KK)=CTMP
        ENDDO
      ENDDO
      DO KK=1,KC
        DO K=1,KC
          BDISP(K,KK,L)=CCTMP(K,KK)
        ENDDO
      ENDDO
      DO K=1,KC
        CCUTMP(K)=FUDISP(K,L)-DT*UP(K)/HMIN
        CCVTMP(K)=FVDISP(K,L)-DT*VP(K)/HMIN
      ENDDO
      DO K=1,KC
        CCUU=0.
        CCVV=0.
        DO KK=1,KC
          CCUU=CCUU+CDISPI(K,KK)*CCUTMP(KK)
          CCVV=CCVV+CDISPI(K,KK)*CCVTMP(KK)
        ENDDO
        FUDISP(K,L)=CCUU
        FVDISP(K,L)=CCVV
      ENDDO
      CCUU=0.
      CCVV=0.
      CCUV=0.
      CCVU=0.
      DO K=1,KC
        CCUU=CCUU+DZC(L,K)*UP(K)*FUDISP(K,L)
        CCUV=CCUV+DZC(L,K)*UP(K)*FVDISP(K,L)
        CCVU=CCVU+DZC(L,K)*VP(K)*FUDISP(K,L)
        CCVV=CCVV+DZC(L,K)*VP(K)*FVDISP(K,L)
      ENDDO
      DXXTCA(L)=DXXTCA(L)+CCUU*HP(L)
      DXYTCA(L)=DXYTCA(L)+CCUV*HP(L)
      DYXTCA(L)=DYXTCA(L)+CCVU*HP(L)
      DYYTCA(L)=DYYTCA(L)+CCVV*HP(L)
      DO K=1,KC
        CCUU=0.
        CCVV=0.
        DO KK=1,KC
          CCUU=CCUU+DZC(L,KK)*UP(KK)*BDISP(KK,K,L)
          CCVV=CCVV+DZC(L,KK)*VP(KK)*BDISP(KK,K,L)
        ENDDO
        CUDISPT(K,L)=CCUU*HP(L)
        CVDISPT(K,L)=CCVV*HP(L)
      ENDDO
    ENDIF
  ENDDO
  IF( N < NTS) RETURN

  ! **  COMPLETE CALCULATION OF DISPERSION COEFFICIENTS
  DO L=2,LA
    IF( LCT(L) == 5 .AND. SPB(L) /= 0. )THEN
      DO KK=1,KC
        DO K=1,KC
          CDISP(K,KK)=-BDISP(K,KK,L)
        ENDDO
      ENDDO
      DO K=1,KC
        CDISP(K,K)=1.+CDISP(K,K)
      ENDDO
      CALL SVDCMP(CDISP,KC,KC,MGM,MGM,WTMP,VVTMP)
      DO K=1,KC
        SVAL(K,L)=WTMP(K)
      ENDDO
      DO K=1,KC
        CRHS(K)=FUDISP(K,L)
      ENDDO
      CALL SVBKSB(CDISP,WTMP,VVTMP,KC,KC,MGM,MGM,CRHS,CSOL)
      CCUU=0.
      CCVU=0.
      DO K=1,KC
        CCUU=CCUU+CUDISPT(K,L)*CSOL(K)
        CCVU=CCVU+CVDISPT(K,L)*CSOL(K)
      ENDDO
      DXXTCA(L)=-(DXXTCA(L)+CCUU)*HMIN/TPN
      DYXTCA(L)=-(DYXTCA(L)+CCVU)*HMIN/TPN
      DO K=1,KC
        CRHS(K)=FVDISP(K,L)
      ENDDO
      CALL SVBKSB(CDISP,WTMP,VVTMP,KC,KC,MGM,MGM,CRHS,CSOL)
      CCVV=0.
      CCUV=0.
      DO K=1,KC
        CCVV=CCVV+CVDISPT(K,L)*CSOL(K)
        CCUV=CCUV+CUDISPT(K,L)*CSOL(K)
      ENDDO
      DYYTCA(L)=-(DYYTCA(L)+CCVV)*HMIN/TPN
      DXYTCA(L)=-(DXYTCA(L)+CCUV)*HMIN/TPN
    ENDIF
  ENDDO
  DO L=2,LA
    DXXTCA(L)=DXXTCA(L)/HLPF(L)
    DXYTCA(L)=DXYTCA(L)/HLPF(L)
    DYXTCA(L)=DYXTCA(L)/HLPF(L)
    DYYTCA(L)=DYYTCA(L)/HLPF(L)
  ENDDO

  if( process_id == master_id )THEN
      ! **  WRITE OUTPUT FILES
      OPEN(88,FILE=OUTDIR//'DISTEN.OUT',STATUS='UNKNOWN')
      CLOSE(88,STATUS='DELETE')
      OPEN(88,FILE=OUTDIR//'DISTEN.OUT',STATUS='UNKNOWN')
      WRITE(88,881)
      DO L=2,LA
        WRITE(88,2011)IL(L),JL(L),DLON(L),DLAT(L),DXXTCA(L),DXYTCA(L),DYXTCA(L),DYYTCA(L)
      ENDDO
      CLOSE(88)
      OPEN(88,FILE=OUTDIR//'UVTSC.OUT',STATUS='UNKNOWN')
      WRITE(88,882)
      DO L=2,LA
        AMCPT=AMCP(L)*GI
        AMSPT=AMSP(L)*GI
        WRITE(88,2012)IL(L),JL(L),DLON(L),DLAT(L),AMCPT,AMSPT,AMCUE(L),AMSUE(L),AMCVE(L),AMSVE(L)
      ENDDO
      CLOSE(88)
      OPEN(88,FILE=OUTDIR//'UVERV.OUT',STATUS='UNKNOWN')
      CLOSE(88,STATUS='DELETE')
      OPEN(88,FILE=OUTDIR//'UVERV.OUT',STATUS='UNKNOWN')
      WRITE(88,883)
      DO L=2,LA
        WRITE(88,2012)IL(L),JL(L),DLON(L),DLAT(L),HLPF(L),UELPF(L),VELPF(L),SALLPF(L,1),SALLPF(L,KC)
      ENDDO
      CLOSE(88)
      OPEN(88,FILE=OUTDIR//'SINVAL.OUT',STATUS='UNKNOWN')
      CLOSE(88,STATUS='DELETE')
      OPEN(88,FILE=OUTDIR//'SINVAL.OUT',STATUS='UNKNOWN')
      DO L=2,LA
        WRITE(88,2013)IL(L),JL(L),(SVAL(K,L),K=1,KC)
      ENDDO
      CLOSE(88)
      
      881 FORMAT(3X,'I',3X,'J',3X,'LON',9X,'LAT',9X,'DXX',10X,'DXY',10X,'DYX',10X,'DYY')
      882 FORMAT(3X,'I',3X,'J',3X,'LON',9X,'LAT',9X,'AMCPT',8X,'AMSPT',8X,'AMCUE',8X,'AMSUE',8X,'AMCVE',8X,'AMSVE')
      883 FORMAT(3X,'I',3X,'J',3X,'LON',9X,'LAT',9X,'HLPF',9X,'UELPF',8X,'VELPF',8X,'SALLPFBOT',4X,'SALLPFSURF')
      2011 FORMAT(2I4,2X,F10.6,2X,F10.6,4(2X,E12.4))
      2012 FORMAT(2I4,2X,F10.6,2X,F10.6,6(2X,E12.4))
      2013 FORMAT(2I4,8(2X,E12.4))
    end if
  RETURN
END

