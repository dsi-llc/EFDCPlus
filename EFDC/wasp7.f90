! ----------------------------------------------------------------------
!   This file is a part of EFDC+
!   Website:  https://eemodelingsystem.com/
!   Repository: https://github.com/dsi-llc/EFDC_Plus.git
! ----------------------------------------------------------------------
! Copyright 2021-2022 DSI, LLC
! Distributed under the GNU GPLv2 License.
! ----------------------------------------------------------------------
SUBROUTINE WASP7

  ! CHANGE RECORD
  ! == == == ==  == 
  ! REVISIONS:
  ! == == == ==  == 
  !  M. MORTON 06/06/94: THIS VERSION WRITES DISPERSION TO THE WASPDH.OUT
  !  M. MORTON 06/07/94: WRITES HYDRODYNAMIC INFORMATION AND DISPERSION TO
  !        DATA GROUP B USE WASPB.MRM  (DO NOT USE WASPB.OUT)
  !        DATA GROUP C USE WASPC.OUT
  !        DATA GROUP D USE WASPD.MRM  (DO NOT USE WASPD.OUT)
  ! == == == == == =
  ! **  SUBROUTINE WASP5 WRITES OUTPUT FILES PROVIDING ADVECTIVE AND
  ! **  DIFFUSIVE TRANSPORT FIELDS FOR THE WASP7 WATER QUALITY MODEL
  !
  ! *** PMC  THIS ROUTINE USES HMP, THE STATIC IC DEPTH.  SHOULDN'T IT USE HP?
  !
  USE GLOBAL

  IMPLICIT NONE

  INTEGER :: LCLTM2,LTYPE,KWASP,LT,LBELOW,I,J,L,K,IONE,LWSPTMP,IZERO,IM1,NTEX,NORSH
  INTEGER :: NORSV,NORS,KMUL,LWASPW,LW,LSLT,LWASPS,LS,KMUL1,KMUL2,NBRK,IBPTMP,NINQ,NOQSH,NOQSV
  INTEGER :: NOQS,LL,LN,NBRKQ,NTEXX,NJUN,NCHNH,NCHNV,NCHN,ISTMP,NODYN,LCHN,LDTM,LUTM,KMUL3
  INTEGER :: LCELL,LCHNUM,IMTMP,IDRTMP,IPTMP,JMTMP,JPTMP,KPTMP,LCELTMP,LE1

  INTEGER(IK4),SAVE,ALLOCATABLE,DIMENSION(:) :: LDTMP
  INTEGER(IK4),SAVE,ALLOCATABLE,DIMENSION(:) :: LUTMP

  REAL    :: SVPT,SCALR,WSS1,WSS2,WSS3,VOLUME,DXYSUM,UNITY,ADDLW,ADDLS,ADDL,TSTOP,TSTART,TSMALL,D1
  REAL    :: T1,D2,T2,D3,T3,D4,T4,D5,T5,D6,T6,DTWASP,TZERO,TENDHYD,RMNDUM,RLENTH,WIDTH,VELTMP,DUMVOL
  REAL    :: DEPTMP,VOLTMP,RZERO,TMPVAL,FLOWX,UDDXTMP,FLOWY,VDDYTMP,FLOWZ,WDDZTMP,QQSUM
  REAL    :: VOLUM,DEPTH,VELX,VELY,VELZ,VELMAG

  REAL(RK4),SAVE,ALLOCATABLE,DIMENSION(:) :: QTMP

  CHARACTER*50 TITLEB,TITLEC
  CHARACTER*80, STATIC :: FILE1
  

  IF(  .NOT. ALLOCATED(LDTMP) )THEN
    ALLOCATE(LDTMP((KCM+1)*LCM))
    ALLOCATE(LUTMP((KCM+1)*LCM))
    ALLOCATE(QTMP((KCM+1)*LCM))
    LDTMP=0.0
    LUTMP=0.0
    QTMP=0.0
  ENDIF
  TITLEB='DATA GROUP B: EXCHANGE COEFFICIENTS'
  TITLEC='DATA GROUP C: VOLUMES'
  !
  ! **  WARNING!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  ! **  THE VALUE OF X IN THE F10.X FORMATS MAY NEED TO BE CHANGED
  ! **  FROM PROBLEM TO PROBLEM.  A PRELIMINARY RUN USING E10.3
  ! **  CAN BE USED TO SPEED THE ADJUSTMENT
  ! **  READ CONTROL DATA FOR WRITING TO WASP COMPATIBLE FILES
  !
  SVPT=1.
  IF( NTSMMT < NTSPTC)SVPT=0.
  IF( JSWASP == 1 )THEN
    WRITE(*,'(A)')'READING EFDC.WSP'
    OPEN(1,FILE='EFDC.WSP',STATUS='UNKNOWN')
    READ(1,1)
    READ(1,1)
    READ(1,*) IVOPT,IBEDV,SCALV,CONVV,VMULT,VEXP,DMULT,DEXP
    READ(1,1)
    READ(1,1)
    READ(1,*) NRFLD,SCALR,CONVR,ISNKH
    READ(1,1)
    READ(1,1)
    READ(1,*) IQOPT,NFIELD,SCALQ,CONVQ,HYDFIL,ISWASPD,ISDHD
    READ(1,1)
    READ(1,1)
    READ(1,*) DEPSED,TDINTS,SEDIFF, WSS1, WSS2, WSS3
    CLOSE(1)
  ENDIF
      1 FORMAT (80X)
  !
  ! **  WRITE HORIZONTAL POSITION AND LAYER FILE WASPP.OUT
  ! **  WRITE INITIAL VOLUME FILE WASPC.OUT
  ! **  FILE WASPC.OUT IS CONSISTENT WITH DATA GROUP C SPECIFICATIONS
  ! **  ON PAGE 11 OF THE WASP5.1 MANUAL PART B, SEPT 1993
  ! **  FILE WASPP.OUT DEFINES THE LAYER (1 IS SURFACE WATER LAYER, WITH
  ! **  LAYER NUMBERING INCREASING WITH DEPTH IN WATER COLUMN) AND
  ! **  HORIZONTAL POSITIONS IN LON,LAT OR UTME, UTMN OF THE WATER
  ! **  QUALITY (LONG TERM TRANSPORT) CELLS OR SEGEMENTS
  !
  IF( JSWASP == 1 )THEN
    OPEN(90,FILE=OUTDIR//'wasp\WASPP.OUT',STATUS='UNKNOWN')
    OPEN(93,FILE=OUTDIR//'wasp\WASPC.OUT',STATUS='UNKNOWN')
    CLOSE(90,STATUS='DELETE')
    CLOSE(93,STATUS='DELETE')
    OPEN(90,FILE=OUTDIR//'wasp\WASPP.OUT',STATUS='UNKNOWN')
    OPEN(93,FILE=OUTDIR//'wasp\WASPC.OUT',STATUS='UNKNOWN')
  !
  !       IVOPT=2
  !       IBEDV=0
  !
    WRITE(93,1031)IVOPT,IBEDV,TDINTS,TITLEC
  !
  !       SCALV=1.
  !       CONVV=1.
  !
    WRITE(93,1032)SCALV,CONVV
  !
  !       VMULT=0.
  !       VEXP=0.
  !       DMULT=0.
  !       DEXP=0.
  !
    LCLTM2=LCLT-2
    LWASP=0
    IF( KC > 1 )THEN
      LTYPE=1
      KWASP=1
      DO LT=2,LALT
        LWASP=LWASP+1
        LBELOW=LWASP+LCLTM2
        I=ILLT(LT)
        J=JLLT(LT)
        L=LIJ(I,J)
        DMULT=HLPF(L)*DZC(L,KC)
        VOLUME=DXYP(L)*HLPF(L)*DZC(L,KC)
        IF( NTSMMT < NTSPTC )THEN
          DMULT=HP(L)*DZC(L,KC)
          VOLUME=DXYP(L)*HP(L)*DZC(L,KC)
        ENDIF
        WRITE(90,1001)LWASP,KWASP,I,J,L,KC
        WRITE(93,1033)LWASP,LBELOW,LTYPE,VOLUME,VMULT,VEXP, &
            DMULT,DEXP,I,J,L,KC
      ENDDO
      LTYPE=2
      DO K=KS,2,-1
        KWASP=KC-K+1
        DO LT=2,LALT
          LWASP=LWASP+1
          LBELOW=LWASP+LCLTM2
          I=ILLT(LT)
          J=JLLT(LT)
          L=LIJ(I,J)
          DMULT=HLPF(L)*DZC(L,K)
          VOLUME=DXYP(L)*HLPF(L)*DZC(L,K)
          IF( NTSMMT < NTSPTC )THEN
            DMULT=HP(L)*DZC(L,KC)
            VOLUME=DXYP(L)*HP(L)*DZC(L,KC)
          ENDIF
          WRITE(90,1001)LWASP,KWASP,I,J,L,K
          WRITE(93,1033)LWASP,LBELOW,LTYPE,VOLUME,VMULT,VEXP, &
              DMULT,DEXP,I,J,L,KC
        ENDDO
      ENDDO
    ENDIF
    LTYPE=2
    IF( KC == 1 ) LTYPE=1
    KWASP=KC
    DO LT=2,LALT
      LWASP=LWASP+1
  !
  !        LBELOW=0
  !
      LBELOW=LWASP+LCLTM2
      I=ILLT(LT)
      J=JLLT(LT)
      L=LIJ(I,J)
      DMULT=HLPF(L)*DZC(L,KSZ(L))
      VOLUME=DXYP(L)*HLPF(L)*DZC(L,KSZ(L))
      IF( NTSMMT < NTSPTC )THEN
        DMULT=HP(L)*DZC(L,KC)
        VOLUME=DXYP(L)*HP(L)*DZC(L,KC)
      ENDIF
      IONE=1
      WRITE(90,1001)LWASP,KWASP,I,J,L,IONE
      WRITE(93,1033)LWASP,LBELOW,LTYPE,VOLUME,VMULT,VEXP, &
          DMULT,DEXP,I,J,L,IONE
    ENDDO
    LTYPE=3
    KWASP=KC+1
    DXYSUM=0.
    LWSPTMP=LWASP+1
    DO LT=2,LALT
      LWSPTMP=LWSPTMP+1
    ENDDO
  !
  ! THE FOLLOWING THE LOWER BENTHIC LAYER.  ALL UPPER BENTHIC LAYER SEGMEN
  ! HAVE THIS LAYER IMMEDIATELY BELOW THEM:
  !
    DO LT=2,LALT
      LWASP=LWASP+1
      LBELOW=LWSPTMP
      I=ILLT(LT)
      J=JLLT(LT)
      L=LIJ(I,J)
      DXYSUM=DXYSUM+DXYP(L)
      VOLUME=DXYP(L)*DEPSED
      IZERO=0
      WRITE(90,1001)LWASP,KWASP,I,J,L,IZERO
      WRITE(93,1033)LWASP,LBELOW,LTYPE,VOLUME,VMULT,VEXP, &
          DEPSED,DEXP,I,J,L,IZERO
    ENDDO
  !
  ! NEXT DO THE LOWER BENTHIC LAYER:
  !
    LTYPE=4
    KWASP=KC+2
    LWASP=LWASP+1
    LBELOW=0
    DMULT=DEPSED
    VOLUME=DXYSUM*DEPSED
    IM1=-1
    WRITE(90,1001)LWASP,KWASP,I,J,L,IM1
    WRITE(93,1033)LWASP,LBELOW,LTYPE,VOLUME,VMULT,VEXP, &
        DMULT,DEXP,I,J,L,IM1
    CLOSE(90)
    CLOSE(93)
  ENDIF
   1001 FORMAT(6I5,2F10.4)
   1031 FORMAT(2I5,F10.4,10X,A50)
   1032 FORMAT(2F10.4)
  !
  ! FORMAT 1033 AS COMMENTED OUT IS TROUBLESOME ... BETTER CHANGE SHOWN
  !
   1033 FORMAT(3I10,F10.1,4F10.3,'   !',4I5)
  !
  ! **  WRITE DIFFUSIVE AND DISPERSIVE TRANSPORT FILE WASPB.OUT
  ! **  FILE WASPB.OUT IS CONSISTENT WITH DATA GROUP B SPECIFICATIONS
  ! **  ON PAGE 8 OF THE WASP5.1 MANUAL PART B, SEPT 1993
  !
  IF( JSWASP == 1 )THEN
    OPEN(91,FILE=OUTDIR//'wasp\WASPB.OUT',STATUS='UNKNOWN')
    CLOSE(91,STATUS='DELETE')
    OPEN(91,FILE=OUTDIR//'wasp\WASPB.OUT',STATUS='UNKNOWN')
    WRITE(91,1011)NRFLD,TITLEB
    NTEX=NTS/NTSMMT
    WRITE(91,1012)NTEX,SCALR,CONVR
    CLOSE(91)
    OPEN(91,FILE=OUTDIR//'wasp\WASPB.OUT',POSITION='APPEND' ,STATUS='UNKNOWN')
    LCLTM2=LCLT-2
    NORSH=0
    NORSV=0
    DO LT=2,LALT
      I=ILLT(LT)
      J=JLLT(LT)
      L=LIJ(I,J)
      NORSH=NORSH+INT(SUBO(L))+INT(SVBO(L))
      NORSV=NORSV+INT(SPB(L))
    ENDDO
    NORS=ISNKH*KC*NORSH+KS*NORSV
    WRITE(91,1013)NORS
    IF( ISNKH == 1 )THEN
      UNITY=1.
      DO K=KC,1,-1
        KMUL=KC-K
        DO LT=2,LALT
          I=ILLT(LT)
          J=JLLT(LT)
          L=LIJ(I,J)
          IF( SUB(L) == 1. )THEN
            LWASP=LT-1+KMUL*LCLTM2
            LWASPW=LWASP-1
            LW=LWC(L)
            ADDLW=DYU(L)*AHULPF(L,K)*DZC(L,K)*0.5*(HLPF(L) &
                +HLPF(LW))*DXIU(L)
            WRITE(91,1014) ADDLW,UNITY,LWASPW,LWASP
          ENDIF
        ENDDO
      ENDDO
    ENDIF
    IF( ISNKH == 1 )THEN
      UNITY=1.
      DO K=KC,1,-1
        KMUL=KC-K
        DO LT=2,LALT
          I=ILLT(LT)
          J=JLLT(LT)
          L=LIJ(I,J)
          IF( SVB(L) == 1. )THEN
            LWASP=LT-1+KMUL*LCLTM2
            LSLT=LSCLT(LT)
            LWASPS=LSLT-1+KMUL*LCLTM2
            LS=LSC(L)
            ADDLS=DXV(L)*AHVLPF(L,K)*DZC(L,K)*0.5*(HLPF(L) &
                +HLPF(LS))*DYIV(L)
            WRITE(91,1014) ADDLS,UNITY,LWASPS,LWASP
          ENDIF
        ENDDO
      ENDDO
    ENDIF
    IF( KC > 1 )THEN
      UNITY=1.
      DO K=KS,1,-1
        KMUL1=KS-K
        KMUL2=KMUL1+1
        DO LT=2,LALT
          I=ILLT(LT)
          J=JLLT(LT)
          L=LIJ(I,J)
          IF( SPB(L) == 1. )THEN
            LWASP=LT-1+KMUL1*LCLTM2
            LBELOW=LT-1+KMUL2*LCLTM2
            ADDL=DXYP(L)*ABLPF(L,K)*DZIG(L,K)
            WRITE(91,1014) ADDL,UNITY,LWASP,LBELOW
          ENDIF
        ENDDO
      ENDDO
    ENDIF
    NBRK=6
    WRITE(91,1015)NBRK
    
    TSTOP=TIMESEC
    TSTART=TSTOP-DT*FLOAT(NTSMMT)
  
    TSTOP=TSTOP/86400.
    TSTART=TSTART/86400.
    TSMALL=1.E-5
    D1=0.
    T1=0.-2*TSMALL
    D2=0.
    T2=TSTART-TSMALL
    D3=1.
    T3=TSTART+TSMALL
    D4=1.
    T4=TSTOP-TSMALL
    D5=0.
    T5=TSTOP+TSMALL
    D6=0.
    T6=2*TSMALL+(DT*FLOAT(NTS)+TBEGIN*TCON)/86400.
    WRITE(91,1016)D1,T1,D2,T2,D3,T3,D4,T4
    WRITE(91,1016)D5,T5,D6,T6
    CLOSE(91)
  !
  ! **  ADD PORE WATER EXCHANGE FIELD ON LAST CALL
  !
    OPEN(91,FILE=OUTDIR//'wasp\WASPB.OUT',POSITION='APPEND' ,STATUS='UNKNOWN')
    NTEX=1
    SCALR=1.
    CONVR=1.
    WRITE(91,1012)NTEX,SCALR,CONVR
    NORSV=0
    DO LT=2,LALT
      I=ILLT(LT)
      J=JLLT(LT)
      L=LIJ(I,J)
      NORSV=NORSV+INT(SPB(L))
    ENDDO
    WRITE(91,1013)NORSV
    IF( KC >= 1 )THEN
      KMUL2=KC+1
      UNITY=1.
      DO LT=2,LALT
        I=ILLT(LT)
        J=JLLT(LT)
        L=LIJ(I,J)
        IF( SPB(L) == 1. )THEN
          LWASP=LT-1+KC*LCLTM2
          LBELOW=LT-1+KMUL2*LCLTM2
          ADDL=2.*DXYP(L)*SEDIFF/DEPSED
          WRITE(91,1014) ADDL,UNITY,LWASP,LBELOW
        ENDIF
      ENDDO
    ENDIF
    NBRK=6
    WRITE(91,1015)NBRK
    IF( ISDYNSTP == 0 )THEN
      TSTOP=DT*FLOAT(N)+TCON*TBEGIN
      TSTART=TSTOP-DT*FLOAT(NTSMMT)
    ELSE
      TSTOP=TIMESEC
      TSTART=TSTOP-DT*FLOAT(NTSMMT)
    ENDIF
    TSTOP=TSTOP/86400.
    TSTART=TSTART/86400.
    TSMALL=1.E-5
    D1=0.
    T1=0.-2*TSMALL
    D2=0.
    T2=TSTART-TSMALL
    D3=1.
    T3=TSTART+TSMALL
    D4=1.
    T4=TSTOP-TSMALL
    D5=0.
    T5=TSTOP+TSMALL
    D6=0.
    T6=2*TSMALL+(DT*FLOAT(NTS)+TBEGIN*TCON)/86400.
    WRITE(91,1016)D1,T1,D2,T2,D3,T3,D4,T4
    WRITE(91,1016)D5,T5,D6,T6
    IBPTMP=0
    WRITE(91,1017)IBPTMP,IBPTMP,IBPTMP,IBPTMP, &
        IBPTMP,IBPTMP,IBPTMP,IBPTMP, &
        IBPTMP,IBPTMP,IBPTMP,IBPTMP, &
        IBPTMP,IBPTMP,IBPTMP,IBPTMP
    CLOSE(91)
  ENDIF
   1011 FORMAT(I5,10X,A50)
   1012 FORMAT(I5,2F10.4)
   1013 FORMAT(I5)
   1014 FORMAT(2E10.3,2I5,F10.3,'   !',3I5,3X,A3)
   1015 FORMAT(I5)
   1016 FORMAT(4(E10.3,F10.5))
   1017 FORMAT(16I5)
  !
  ! **  WRITE ADVECTIVE TRANSPORT FILE WASPD.OUT
  ! **  FILE WASPD.OUT IS CONSISTENT WITH DATA GROUP D.1 SPECIFICATIONS
  ! **  ON PAGE 13 OF THE WASP5.1 MANUAL PART B, SEPT 1993
  ! **  THIS FILE IS WRITTEN ONLY IF ISWASPD=1
  !!!!!!!!!!!CHANGES ON NEXT 2 LINES
  !
  IF( ISWASPD == 1 )THEN
    IF( JSWASP == 1 )THEN
      OPEN(92,FILE=OUTDIR//'wasp\WASPD.OUT',STATUS='UNKNOWN')
      CLOSE(92,STATUS='DELETE')
      OPEN(92,FILE=OUTDIR//'wasp\WASPD.OUT',STATUS='UNKNOWN')
  !
  !       IQOPT=1
  !       NFIELD=1
  !
      WRITE(92,1021)IQOPT,NFIELD,HYDFIL
      NINQ=NTS/NTSMMT
  !
  !       SCALQ=1
  !       CONVQ=1
  !
      WRITE(92,1022)NINQ,SCALQ,CONVQ
      CLOSE(92)
    ENDIF
    OPEN(92,FILE=OUTDIR//'wasp\WASPD.OUT',POSITION='APPEND' ,STATUS='UNKNOWN')
    LCLTM2=LCLT-2
    NOQSH=0
    NOQSV=0
    DO LT=2,LALT
      I=ILLT(LT)
      J=JLLT(LT)
      L=LIJ(I,J)
  !
  !!!!!!!!!!!!!!!CHANGES ON NEXT 3 LINES
  !
      NOQSH=NOQSH+INT(SUBO(L))+INT(SVBO(L))
      IF( IJCTLT(I+1,J) == 8 ) NOQSH=NOQSH+1
      IF( IJCTLT(I,J+1) == 8 ) NOQSH=NOQSH+1
      NOQSV=NOQSV+INT(SWB(L))
    ENDDO
    NOQS=KC*NOQSH+KS*NOQSV
    WRITE(92,1023)NOQS
    LL=0
    DO K=KC,1,-1
      KMUL=KC-K
      DO LT=2,LALT
        I=ILLT(LT)
        J=JLLT(LT)
        L=LIJ(I,J)
  !
  !!!!!!!!!!!!!!CHANGES ON NEXT 15 LINES
  !
        IF( SUBO(L) == 1. )THEN
          LL=LL+1
          LDTMP(LL)=LT-1+KMUL*LCLTM2
          LUTMP(LL)=LDTMP(LL)-1
          IF( IJCTLT(I-1,J) == 8 ) LUTMP(LL)=0
          QTMP(LL)=DYU(L)*(UHLPF(L,K)+SVPT*UVPT(L,K))*DZC(L,K)
        ENDIF
        IF( IJCTLT(I+1,J) == 8 )THEN
          IF( SUBO(LEC(L)) == 1. )THEN
            LL=LL+1
            LDTMP(LL)=0
            LUTMP(LL)=LT-1+KMUL*LCLTM2
            QTMP(LL)=DYU(LEC(L))*(UHLPF(LEC(L),K)+SVPT*UVPT(LEC(L),K))*DZC(L,K)
          ENDIF
        ENDIF
      ENDDO
      DO LT=2,LALT
        I=ILLT(LT)
        J=JLLT(LT)
        L=LIJ(I,J)
  !
  !!!!!!!!!!!!!!CHANGES ON NEXT 16 LINES
  !
        IF( SVBO(L) == 1. )THEN
          LL=LL+1
          LSLT=LSCLT(LT)
          LDTMP(LL)=LT-1+KMUL*LCLTM2
          LUTMP(LL)=LSLT-1+KMUL*LCLTM2
          IF( IJCTLT(I,J-1) == 8 ) LUTMP(LL)=0
          QTMP(LL)=DXV(L)*(VHLPF(L,K)+SVPT*VVPT(L,K))*DZC(L,K)
        ENDIF
        IF( IJCTLT(I,J+1) == 8 )THEN
          LN=LNC(L)
          IF( SVBO(LN) == 1 )THEN
            LL=LL+1
            LDTMP(LL)=0
            LUTMP(LL)=LT-1+KMUL*LCLTM2
            QTMP(LL)=DXV(LN)*(VHLPF(LN,K)+SVPT*VVPT(LN,K))*DZC(L,K)
          ENDIF
        ENDIF
      ENDDO
    ENDDO
    IF( KC > 1 )THEN
      DO K=KS,1,-1
        KMUL1=KS-K
        KMUL2=KMUL1+1
        DO LT=2,LALT
          I=ILLT(LT)
          J=JLLT(LT)
          L=LIJ(I,J)
          IF( SWB(L) == 1. )THEN
            LL=LL+1
            LUTMP(LL)=LT-1+KMUL1*LCLTM2
            LDTMP(LL)=LT-1+KMUL2*LCLTM2
            QTMP(LL)=-DXYP(L)*(WLPF(L,K)+SVPT*WVPT(L,K))
          ENDIF
        ENDDO
      ENDDO
    ENDIF
    DO L=1,LL,4
      LE1=LEC(LEC(L))
      WRITE(92,1024) QTMP(L),  LUTMP(L),  LDTMP(L), &
          QTMP(LEC(L)),LUTMP(LEC(L)),LDTMP(LEC(L)), &
          QTMP(LE1),LUTMP(LE1),LDTMP(LE1), &
          QTMP(LEC(LE1)),LUTMP(LEC(LE1)),LDTMP(LEC(LE1))
    ENDDO
    NBRKQ=6
    WRITE(92,1025)NBRKQ
    WRITE(92,1026)D1,T1,D2,T2,D3,T3,D4,T4
    WRITE(92,1026)D5,T5,D6,T6
    CLOSE(92)
  !
  !!!!!!!!!!!CHANGES ON NEXT 2 LINES
  !
  ENDIF
   1021 FORMAT(2I5,A12)
   1022 FORMAT(I5,2F10.4)
   1023 FORMAT(I5)
   1024 FORMAT(1P,4(E10.3,2I5))
   1025 FORMAT(I5)
   1026 FORMAT(4(2F10.5))
  !
  ! *** *******************************************************************C
  ! M.R. MORTON'S VERSION OF WASP DATA GROUP D
  ! **  WRITE ADVECTIVE TRANSPORT FILE WASPD.MRM
  !----------------------------------------------------------------------C
  !
  IF( JSWASP  ==  1 )THEN
    OPEN(92,FILE=OUTDIR//'wasp\WASPD.MRM',STATUS='UNKNOWN')
    WRITE(92,2020) IQOPT,NFIELD,HYDFIL
    LL=0
    NINQ=0
    SCALQ=1.0
    CONVQ=1.0/86400.0
  !
  ! DATA BLOCK D.1 (ADVECTIVE FLOWS) IS NOT NEEDED SINCE HYD FILE IS USED:
  ! DATA BLOCK D.2 (PORE WATER FLOWS) NOT NEEDED:
  !
    WRITE(92,2022) NINQ,SCALQ,CONVQ
  !
  ! DATA BLOCK D.3 (SEDIMENT #1 TRANSPORT FIELD):
  !
    NINQ=1
    WRITE(92,2023) NINQ,SCALQ,CONVQ
    IF( KC > 1 )THEN
      DO K=KS,0,-1
        KMUL1=KS-K
        KMUL2=KMUL1+1
        DO LT=2,LALT
  !
  !              CALL F_FLUSHNOW(6)
  !
          I=ILLT(LT)
  !
  !              CALL F_FLUSHNOW(6)
  !
          J=JLLT(LT)
  !
  !              CALL F_FLUSHNOW(6)
  !
          L=LIJ(I,J)
  !
  !              CALL F_FLUSHNOW(6)
  !
          IF( SWB(L) == 1. )THEN
            LL=LL+1
            LUTMP(LL)=LT-1+KMUL1*LCLTM2
            LDTMP(LL)=LT-1+KMUL2*LCLTM2
  !
  ! QTMP ARRAY WILL HOLD THE PLAN VIEW AREA OF EACH CELL:
  !
            QTMP(LL)= DXYP(L)
          ENDIF
        ENDDO
      ENDDO
    ENDIF
  !
  !
  !
   6999 FORMAT(9I5,F5.1)
   6996 FORMAT(9I5,F5.1)
    WRITE(92,2030) LL
    DO L=1,LL,4
      LE1=LEC(LEC(L))
      WRITE(92,1024) QTMP(L),  LUTMP(L),  LDTMP(L), &
          QTMP(LEC(L)),LUTMP(LEC(L)),LDTMP(LEC(L)), &
          QTMP(LE1),LUTMP(LE1),LDTMP(LE1), &
          QTMP(LEC(LE1)),LUTMP(LEC(LE1)),LDTMP(LEC(LE1))
    ENDDO
    NBRKQ=2
    T1=1.0
    T2=366.0
    WRITE(92,2030) NBRKQ
    WRITE(92,2031) WSS1,T1,WSS1,T2
  !
  ! DATA BLOCK D.4 (SEDIMENT #2 TRANSPORT FIELD):
  !
    NINQ=1
    WRITE(92,2024) NINQ,SCALQ,CONVQ
    WRITE(92,2030) LL
    DO L=1,LL,4
      LE1=LEC(LEC(L))
      WRITE(92,1024) QTMP(L),  LUTMP(L),  LDTMP(L), &
          QTMP(LEC(L)),LUTMP(LEC(L)),LDTMP(LEC(L)), &
          QTMP(LE1),LUTMP(LE1),LDTMP(LE1), &
          QTMP(LEC(LE1)),LUTMP(LEC(LE1)),LDTMP(LEC(LE1))
    ENDDO
    NBRKQ=2
    T1=1.0
    T2=366.0
    WRITE(92,2030) NBRKQ
    WRITE(92,2031) WSS2,T1,WSS2,T2
  !
  ! DATA BLOCK D.5 (SEDIMENT #3 TRANSPORT FIELD):
  !
    NINQ=1
    WRITE(92,2025) NINQ,SCALQ,CONVQ
    WRITE(92,2030) LL
    DO L=1,LL,4
      LE1=LEC(LEC(L))
      WRITE(92,1024) QTMP(L),  LUTMP(L),  LDTMP(L), &
          QTMP(LEC(L)),LUTMP(LEC(L)),LDTMP(LEC(L)), &
          QTMP(LE1),LUTMP(LE1),LDTMP(LE1), &
          QTMP(LEC(LE1)),LUTMP(LEC(LE1)),LDTMP(LEC(LE1))
    ENDDO
    NBRKQ=2
    T1=1.0
    T2=366.0
    WRITE(92,2030) NBRKQ
    WRITE(92,2031) WSS3,T1,WSS3,T2
  !
  ! ADD SYSTEM BYPASS ARRAY TO BOTTOM OF DATA GROUP D:
  !
    WRITE(92,1017)IBPTMP,IBPTMP,IBPTMP,IBPTMP, &
        IBPTMP,IBPTMP,IBPTMP,IBPTMP, &
        IBPTMP,IBPTMP,IBPTMP,IBPTMP, &
        IBPTMP,IBPTMP,IBPTMP,IBPTMP
    CLOSE(92)
  ENDIF
   2020 FORMAT(2I5,A12,'    DATA GROUP D: FLOWS')
   2021 FORMAT(1P,I5,2E10.3,'    DATA BLOCK D.1 ADVECTIVE FLOWS')
   2022 FORMAT(1P,I5,2E10.3,'    DATA BLOCK D.2 PORE WATER FLOWS')
   2023 FORMAT(1P,I5,2E10.3,'    DATA BLOCK D.3 SED. #1 TRANSPORT FIELD')
   2024 FORMAT(1P,I5,2E10.3,'    DATA BLOCK D.4 SED. #2 TRANSPORT FIELD')
   2025 FORMAT(1P,I5,2E10.3,'    DATA BLOCK D.5 SED. #3 TRANSPORT FIELD')
   2030 FORMAT(I5)
   2031 FORMAT(2(E10.3,F10.5))
  !
  ! **  WRITE TO EXTERNAL HYDRO FILE WASPDH.OUT AND DIAGNOSTIC VERSION
  ! **  OF SAME FILE WASPDHD.OUT
  !
  IF( JSWASP == 1 )THEN
    FILE1=OUTDIR//'wasp\'//HYDFIL
    OPEN(90,FILE=OUTDIR//'wasp\WASPDHD.OUT',STATUS='UNKNOWN')
    IF( IQOPT == 3 ) OPEN(94,FILE=FILE1,STATUS='UNKNOWN')
    IF( IQOPT == 4 ) OPEN(95,FILE=FILE1,STATUS='UNKNOWN', FORM='UNFORMATTED')
    OPEN(96,FILE=OUTDIR//'wasp\WASPB.MRM',STATUS='UNKNOWN')
    CLOSE(90,STATUS='DELETE')
    IF( IQOPT == 3 ) CLOSE(94,STATUS='DELETE')
    IF( IQOPT == 4 ) CLOSE(95,STATUS='DELETE')
    CLOSE(96,STATUS='DELETE')
    OPEN(90,FILE=OUTDIR//'wasp\WASPDHD.OUT',STATUS='UNKNOWN')
    IF( IQOPT == 3 ) OPEN(94,FILE=FILE1,STATUS='UNKNOWN')
    IF( IQOPT == 4 ) OPEN(95,FILE=FILE1,STATUS='UNKNOWN', FORM='UNFORMATTED')
    OPEN(96,FILE=OUTDIR//'wasp\WASPB.MRM',STATUS='UNKNOWN')
    WRITE(96,1011) NRFLD,TITLEB
    NTEXX=1
    WRITE(96,1012) NTEXX,SCALR,CONVR
  !
  ! WRITE WASP5 HYDRODYNAMIC FILE DATA RECORD 1, DATA OPTIONS:
  !  NJUN = NUMBER OF SEGMENTS CONNECTED BY FLOWS FROM THE HYD. FILE
  !  NCHN = NUMBER OF INTERFACIAL FLOW PAIRS FROM THE HYD. FILE
  !  DTWASP = WASP5 TIME STEP (SECONDS)
  !  TZERO = BEGIN TIME STEP FOR HYD. FILE (SECONDS)
  !  TENDHYD = END TIME STEP FOR HYD. FILE (SECONDS)
  !  ISTMP = CONTROL SWITCH, 0=TIME VARIABLE SEGMENT DEPTHS AND VELOCITIES
  !          ARE READ; 1=TIME VARIABLE SEGMENT DEPTHS AND VELOCITIES ARE N
  !          READ.
  !        NCHNC(KL)=0
  !         LCHNC(KL,M)=0
  !
    NJUN=KC*(LCLT-2)
    NCHNH=0
    NCHNV=0
  !
  !!!!!!!!!CHANGES NEXT 13 LINES
  !
    DO LT=2,LALT
      I=ILLT(LT)
      J=JLLT(LT)
      L=LIJ(I,J)
      NCHNH=NCHNH+INT(SUBO(L))
      IF( IJCTLT(I+1,J) == 8 )THEN
        IF( SUBO(LEC(L)) == 1.) NCHNH=NCHNH+1
      ENDIF
      NCHNH=NCHNH+INT(SVBO(L))
      IF( IJCTLT(I,J+1) == 8 )THEN
        IF( SVBO(LNC(L)) == 1.) NCHNH=NCHNH+1
      ENDIF
      NCHNV=NCHNV+INT(SWB(L))
    ENDDO
    NCHN=KC*NCHNH+KS*NCHNV
    ISTMP=0
    NODYN=NFLTMT
    NODYN=NODYN
    DTWASP = DT * FLOAT(NTSMMT)
    TZERO=TBEGIN*TCON
    TENDHYD=TZERO+NTS*DT
    WRITE(90,901)NJUN,NCHN
    IF( IQOPT == 3 )THEN
      WRITE(94,941) NJUN,NCHN, DTWASP, TZERO,TENDHYD,ISTMP
    ENDIF
    IF( IQOPT == 4 )THEN
      WRITE(95) NJUN,NCHN, DTWASP, TZERO,TENDHYD,ISTMP
    ENDIF
    WRITE(96,1013) NCHN
  !
  ! **  CHANNEL DATA
  ! WRITE WASP5 HYDRODYNAMIC FILE DATA RECORD 2, SEGMENT INTERFACE PAIRS:
  !   WASP EXPECTS TO SEE BOUNDARY SEGMENTS DESIGNATED AS "0".
  !
    RMNDUM=0.
    LCHN=0
    DO K=KC,1,-1
      KMUL=KC-K
  !
  !!!!!!!!!!!!!!!CHANGES ON NEXT 38 LINES
  !
      DO LT=2,LALT
        I=ILLT(LT)
        J=JLLT(LT)
        L=LIJ(I,J)
        IF( SUBO(L) == 1. )THEN
          LDTM=LT-1+KMUL*LCLTM2
          LUTM=LDTM-1
          IF( IJCTLT(I-1,J) == 8 ) LUTM=0
          RLENTH=DXU(L)
          WIDTH=DYU(L)
          LCHN=LCHN+1
  !
  !             LCHNC(LDTM,NCHNC(LDTM))=LCHN
  !             LCHNC(LUTM,NCHNC(LUTM))=LCHN
  !
          IF( ISDHD == 1 ) WRITE(90,902)LCHN,RLENTH,WIDTH, &
              RMNDUM,LUTM,LDTM
  IF( ISDHD  ==  2) WRITE(90,'(2I5)') LUTM,LDTM
  IF( IQOPT == 3 ) WRITE(94,9941) LUTM,LDTM,I,J,K,'U 0'
          IF( IQOPT == 4 ) WRITE(95) LUTM,LDTM
  WRITE(96,1014) UNITY,UNITY,LUTM,LDTM,UNITY,I,J,K,'U 0'
  ENDIF
        IF( IJCTLT(I+1,J) == 8 )THEN
          IF( SUBO(LEC(L)) == 1. )THEN
            LDTM=0
            LUTM=LT-1+KMUL*LCLTM2
            RLENTH=DXU(LEC(L))
            WIDTH=DYU(LEC(L))
            LCHN=LCHN+1
  !
  !               LCHNC(LDTM,NCHNC(LDTM))=LCHN
  !               LCHNC(LUTM,NCHNC(LUTM))=LCHN
  !
            IF( ISDHD  ==  1) WRITE(90,902) LCHN,RLENTH,WIDTH, &
                RMNDUM,LUTM,LDTM
  IF( ISDHD  ==  2) WRITE(90,'(2I5)') LUTM,LDTM
  IF( IQOPT == 3 ) WRITE(94,9941) LUTM,LDTM,I,J,K,'U+1'
            IF( IQOPT == 4 ) WRITE(95) LUTM,LDTM
            UNITY=1.0
  WRITE(96,1014) UNITY,UNITY,LUTM,LDTM,UNITY,I,J,K,'U+1'
  ENDIF
  ENDIF
  ENDDO
  !
  !!!!!!!!!CHANGES NEXT 41 LINES
  !
      DO LT=2,LALT
        I=ILLT(LT)
        J=JLLT(LT)
        L=LIJ(I,J)
        IF( SVBO(L) == 1. )THEN
          LSLT=LSCLT(LT)
          LDTM=LT-1+KMUL*LCLTM2
          LUTM=LSLT-1+KMUL*LCLTM2
          IF( IJCTLT(I,J-1) == 8 ) LUTM=0
          RLENTH=DYV(L)
          WIDTH=DXV(L)
          LCHN=LCHN+1
  !
  !             LCHNC(LDTM,NCHNC(LDTM))=LCHN
  !             LCHNC(LUTM,NCHNC(LUTM))=LCHN
  !
          IF( ISDHD  ==  1) WRITE(90,902) LCHN,RLENTH,WIDTH, &
              RMNDUM,LUTM,LDTM
  IF( ISDHD  ==  2) WRITE(90,'(2I5)') LUTM,LDTM
  IF( IQOPT == 3 ) WRITE(94,9941) LUTM,LDTM,I,J,K,'V 0'
          IF( IQOPT == 4 ) WRITE(95) LUTM,LDTM
  WRITE(96,1014) UNITY,UNITY,LUTM,LDTM,UNITY,I,J,K,'V 0'
  ENDIF
        IF( IJCTLT(I,J+1) == 8 )THEN
          LN=LNC(L)
          IF( SVBO(LN) == 1. )THEN
            LSLT=LSCLT(LT)
            LDTM=0
            LUTM=LT-1+KMUL*LCLTM2
            RLENTH=DYV(LN)
            WIDTH=DXV(LN)
            LCHN=LCHN+1
  !
  !               LCHNC(LDTM,NCHNC(LDTM))=LCHN
  !               LCHNC(LUTM,NCHNC(LUTM))=LCHN
  !
            IF( ISDHD  ==  1) WRITE(90,902) LCHN,RLENTH,WIDTH, &
                RMNDUM,LUTM,LDTM
  IF( ISDHD  ==  2) WRITE(90,'(2I5)') LUTM,LDTM
            IF( IQOPT == 3 ) WRITE(94,9941) LUTM,LDTM,UNITY,I, &
                J,K,'V+1'
            IF( IQOPT == 4 ) WRITE(95) LUTM,LDTM
  WRITE(96,1014) UNITY,UNITY,LUTM,LDTM,UNITY,I,J,K,'V+1'
  ENDIF
  ENDIF
  ENDDO
  ENDDO
    IF( KC > 1 )THEN
      DO K=KS,1,-1
        KMUL1=KS-K
        KMUL2=KMUL1+1
        DO LT=2,LALT
          I=ILLT(LT)
          J=JLLT(LT)
          L=LIJ(I,J)
          IF( SWB(L) == 1. )THEN
            LUTM=LT-1+KMUL1*LCLTM2
            LDTM=LT-1+KMUL2*LCLTM2
            RLENTH=HLPF(L)*DZG(L,K)
            WIDTH=SQRT(DXYP(L))
            LCHN=LCHN+1
  !
  !               LCHNC(LDTM,NCHNC(LDTM))=LCHN
  !               LCHNC(LUTM,NCHNC(LUTM))=LCHN
  !
            WRITE(90,902)LCHN,RLENTH,WIDTH,RMNDUM,LUTM,LDTM
  IF( IQOPT == 3 ) WRITE(94,9941)LUTM,LDTM,I,J,K,'W 0'
            IF( IQOPT == 4 ) WRITE(95) LUTM,LDTM
  WRITE(96,1014) UNITY,UNITY,LUTM,LDTM,UNITY,I,J,K,'W 0'
  ENDIF
  ENDDO
  ENDDO
  !
  ! WRITE OUT TIME SERIES OF ZERO DISPERSION COEFFICIENTS:
  !
      D1=0.0
      T1=TZERO/TCON
      D2=0.0
      T2=TENDHYD/TCON
      NBRKQ=2
      WRITE(96,905) NBRKQ
      WRITE(96,1016) D1,T1, D2,T2
  !
  ! FOR EXCHANGE BETWEEN THE LOWER WATER SURFACE LAYER AND THE UPPER
  ! BENTHIC LAYER, DO THE FOLLOWING:
  !
      WRITE(96,1012) NTEXX,SCALR,CONVR
      NTEXX=0
      DO K=1,1
        DO LT=2,LALT
          I=ILLT(LT)
          J=JLLT(LT)
          L=LIJ(I,J)
          IF( SWB(L) == 1. )THEN
            NTEXX=NTEXX+1
          ENDIF
        ENDDO
      ENDDO
      WRITE(96,1013) NTEXX
      DO K=1,1
        KMUL1=KS-K
        KMUL2=KMUL1+1
        KMUL3=KMUL2+1
        DO LT=2,LALT
          I=ILLT(LT)
          J=JLLT(LT)
          L=LIJ(I,J)
          IF( SWB(L) == 1. )THEN
            LUTM=LT-1+KMUL2*LCLTM2
            LDTM=LT-1+KMUL3*LCLTM2
            WRITE(96,1014) DXYP(L),DEPSED,LUTM,LDTM
          ENDIF
        ENDDO
      ENDDO
  !
  ! WRITE OUT TIME SERIES OF WATER-BENTHIC EXCHANGE DISPERSION COEFFICIENT
  !
      D1=SEDIFF
      T1=TZERO/TCON
      D2=SEDIFF
      T2=TENDHYD/TCON
      NBRKQ=2
      WRITE(96,905) NBRKQ
      WRITE(96,1016) D1,T1, D2,T2
      IBPTMP=0
      WRITE(96,1017)IBPTMP,IBPTMP,IBPTMP,IBPTMP, &
          IBPTMP,IBPTMP,IBPTMP,IBPTMP, &
          IBPTMP,IBPTMP,IBPTMP,IBPTMP, &
          IBPTMP,IBPTMP,IBPTMP,IBPTMP
    ENDIF
  !
  ! **  JUNCTION DATA WITH INITIAL CONDITIONS
  ! WRITE WASP5 HYDRODYNAMIC FILE DATA RECORD 3, INITIAL SEGMENT PROPERTIE
  !
    VELTMP=0.
    DUMVOL=0.
    DO K=KC,1,-1
      KMUL=KC-K
      DO LT=2,LALT
        I=ILLT(LT)
        J=JLLT(LT)
        L=LIJ(I,J)
        LCELL=LT-1+KMUL*LCLTM2
        DEPTMP=HLPF(L)*DZC(L,K)
        VOLTMP=DEPTMP*DXYP(L)
        IF( NTSMMT < NTSPTC )THEN
          DEPTMP=HP(L)*DZC(L,K)
          VOLTMP=DEPTMP*DXYP(L)
        ENDIF
        IF( ISDHD  ==  1) WRITE(90,904) LCELL,VOLTMP,I,J
        IF( IQOPT == 3 ) WRITE(94,9440) VOLTMP,DEPTMP,VELTMP
        IF( IQOPT == 4 ) WRITE(95) VOLTMP,DEPTMP,VELTMP
      ENDDO
    ENDDO
    CLOSE(90)
    IF( IQOPT == 3 ) CLOSE(94)
    IF( IQOPT == 4 ) CLOSE(95)
    CLOSE(96)
  ENDIF
  !
  ! **  WRITE TIME STEP, VOLUME AND FLOW DATA
  !
  OPEN(90,FILE=OUTDIR//'wasp\WASPDHD.OUT',POSITION='APPEND' ,STATUS='UNKNOWN')
  IF( IQOPT == 3 )THEN
    OPEN(94,FILE=FILE1,ACCESS='APPEND',STATUS='UNKNOWN')
  END IF
  IF( IQOPT == 4 )THEN
    OPEN(95,FILE=FILE1,ACCESS='APPEND',STATUS='UNKNOWN', FORM='UNFORMATTED')
  END IF
  LCLTM2=LCLT-2
  IZERO=0
  RZERO=0
  IZERO=IZERO
  RZERO=RZERO
  !
  ! WRITE WASP5 HYDRODYNAMIC FILE DATA RECORD 4, BQ(J) FLOW IN INTERFACE
  ! PAIR "J":
  ! ADVECTION AND DISPERSION IN THE X-DIRECTION:
  !
  LCHNUM=0
  DO K=KC,1,-1
    DO LT=2,LALT
      I=ILLT(LT)
      J=JLLT(LT)
      L=LIJ(I,J)
  !
  ! +++++ FOLLOWING LINES BY M. MORTON TO INPUT DISPERSION TO HYD FILE:
  !
      ADDLW=0.0
      IF( SUB(L) == 1. )THEN
        LW=LWC(L)
        ADDLW=DYU(L)*AHULPF(L,K)*DZC(L,K)*0.5*(HLPF(L) &
            +HLPF(LW))*DXIU(L)
      ENDIF
  !
  ! +++++ ABOVE ADDED BY M. MORTON
  !!!!!!!!!CHANGES NEXT 12 LINES
  !
      IF( SUBO(L) == 1. )THEN
        TMPVAL=UHLPF(L,K)+SVPT*UVPT(L,K)
        FLOWX=DYU(L)*TMPVAL*DZC(L,K)
        UDDXTMP=2.*TMPVAL*DXIU(L)/(HLPF(L)+HLPF(LWC(L)))
        IMTMP=I-1
        LCHNUM=LCHNUM+1
        IDRTMP=1
        IF( ISDHD  ==  1) WRITE(90,944) FLOWX,IMTMP,I,J,K
        IF( IQOPT == 3 ) WRITE(94,9946) FLOWX,UDDXTMP,ADDLW,IDRTMP
        IF( IQOPT == 4 ) WRITE(95) FLOWX,UDDXTMP,ADDLW,IDRTMP
      ENDIF
      IF( IJCTLT(I+1,J) == 8 )THEN
        IF( SUBO(LEC(L)) == 1. )THEN
          TMPVAL=UHLPF(LEC(L),K)+SVPT*UVPT(LEC(L),K)
          FLOWX=DYU(LEC(L))*TMPVAL*DZC(L,K)
          UDDXTMP=2.*TMPVAL*DXIU(LEC(L))/(HLPF(LEC(L))+HLPF(L))
          IPTMP=I+1
          LCHNUM=LCHNUM+1
          IDRTMP=1
          IF( ISDHD  ==  1) WRITE(90,944) LCHNUM,FLOWX,I,IPTMP,J,K
          IF( IQOPT == 3 ) WRITE(94,9946) FLOWX,UDDXTMP,ADDLW,IDRTMP
          IF( IQOPT == 4 ) WRITE(95) FLOWX,UDDXTMP,ADDLW,IDRTMP
        ENDIF
      ENDIF
    ENDDO
  !
  ! ADVECTION AND DISPERSION IN THE Y-DIRECTION:
  !
    DO LT=2,LALT
      I=ILLT(LT)
      J=JLLT(LT)
      L=LIJ(I,J)
  !
  ! +++++ FOLLOWING LINES BY M. MORTON TO INPUT DISPERSION TO HYD FILE:
  !
      ADDLS=0.0
      IF( SVB(L) == 1. )THEN
        LS=LSC(L)
        ADDLS=DXV(L)*AHVLPF(L,K)*DZC(L,K)*0.5*(HLPF(L) &
            +HLPF(LS))*DYIV(L)
      ENDIF
  !
  ! +++++ ABOVE ADDED BY M. MORTON
  !!!!!!!!CHANGES NEXT 13 LINES
  !
      IF( SVBO(L) == 1. )THEN
        TMPVAL=VHLPF(L,K)+SVPT*VVPT(L,K)
        FLOWY=DXV(L)*TMPVAL*DZC(L,K)
        VDDYTMP=2.*TMPVAL*DYIV(L)/(HLPF(L)+HLPF(LSC(L)))
        JMTMP=J-1
        LCHNUM=LCHNUM+1
        IDRTMP=2
        IF( ISDHD  ==  1) WRITE(90,944) LCHNUM,FLOWY,I,JMTMP,J,K
        IF( IQOPT == 3 ) WRITE(94,9946) FLOWY,VDDYTMP,ADDLS,IDRTMP
        IF( IQOPT == 4 ) WRITE(95) FLOWY,VDDYTMP,ADDLS,IDRTMP
      ENDIF
      IF( IJCTLT(I,J+1) == 8 )THEN
        LN=LNC(L)
        IF( SVBO(LN) == 1. )THEN
          TMPVAL=VHLPF(LN,K)+SVPT*VVPT(LN,K)
          FLOWY=DXV(LN)*TMPVAL*DZC(L,K)
          VDDYTMP=2.*TMPVAL*DYIV(LN)/(HLPF(LN)+HLPF(L))
          JPTMP=J+1
          LCHNUM=LCHNUM+1
          IDRTMP=2
          IF( ISDHD  ==  1) WRITE(90,944) LCHNUM,FLOWY,I,J,JPTMP,K
          IF( IQOPT == 3 ) WRITE(94,9946) FLOWY,VDDYTMP,ADDLS,IDRTMP
          IF( IQOPT == 4 ) WRITE(95) FLOWY,VDDYTMP,ADDLS,IDRTMP
        ENDIF
      ENDIF
    ENDDO
  ENDDO
  !
  ! ADVECTION AND DISPERSION IN THE Z-DIRECTION:
  !
  IF( KC > 1 )THEN
    DO K=KS,1,-1
      DO LT=2,LALT
        I=ILLT(LT)
        J=JLLT(LT)
        L=LIJ(I,J)
  !
  ! +++++ FOLLOWING LINES BY M. MORTON TO INPUT DISPERSION TO HYD FILE:
  !
        ADDL=0.0
        IF( SPB(L) == 1. )THEN
          ADDL=DXYP(L)*ABLPF(L,K)*DZIG(L,K)
  IF( ISDHD  ==  2) WRITE(90, '(4I5,E13.4)') I,J,K,L,ABLPF(L,K)
  ENDIF
  !
  ! +++++ ABOVE ADDED BY M. MORTON
  !
        IF( SWB(L) == 1 )THEN
          TMPVAL=WLPF(L,K)+SVPT*WVPT(L,K)
          FLOWZ=-DXYP(L)*TMPVAL
          WDDZTMP=TMPVAL*DZIG(L,K)/HLPF(L)
          KPTMP=K+1
          IDRTMP=3
          LCHNUM=LCHNUM+1
          IF( ISDHD  ==  1) WRITE(90,944) LCHNUM,FLOWZ,I,J,K,KPTMP
          IF( IQOPT == 3 ) WRITE(94,9946) FLOWZ,WDDZTMP,ADDL,IDRTMP
          IF( IQOPT == 4 ) WRITE(95) FLOWZ,WDDZTMP,ADDL,IDRTMP
        ENDIF
      ENDDO
    ENDDO
  ENDIF
  !
  ! WRITE WASP5 HYDRODYNAMIC FILE DATA RECORD 5, SEGMENT PROPERTIES:
  !
  QQSUM=0.
  LCELTMP=0
  DO K=KC,1,-1
    DO LT=2,LALT
      LCELTMP=LCELTMP+1
      I=ILLT(LT)
      J=JLLT(LT)
      L=LIJ(I,J)
      LN=LNC(L)
      VOLUM=DXYP(L)*HLPF(L)*DZC(L,K)
      IF( NTSMMT < NTSPTC) VOLUM=DXYP(L)*HP(L)*DZC(L,K)
      DEPTH=HLPF(L)*DZC(L,K)
      VELX=0.5*(UHLPF(L,K)+SVPT*UVPT(L,K) &
          +UHLPF(LEC(L),K)+SVPT*UVPT(LEC(L),K))/HLPF(L)
      VELY=0.5*(VHLPF(L,K)+SVPT*VVPT(L,K) &
          +VHLPF(LN,K)+SVPT*VVPT(LN,K))/HLPF(L)
      VELZ=0.5*(WLPF(L,K-1)+SVPT*WVPT(L,K-1) &
          +WLPF(L,K)+SVPT*WVPT(L,K))
      VELMAG=SQRT(VELX*VELX+VELY*VELY+VELZ*VELZ)
      IF( ISDHD  ==  1) WRITE(90,902) LCELTMP,VOLUM,I,J,K
      IF( IQOPT == 3 ) WRITE(94,946) VOLUM,DEPTH,VELMAG
      IF( IQOPT == 4 ) WRITE(95) VOLUM, DEPTH, VELMAG
    ENDDO
  ENDDO
  CLOSE(90)
  IF( IQOPT == 3 ) CLOSE(94)
  IF( IQOPT == 4 ) CLOSE(95)
    901 FORMAT(2I5,E12.5,4I5,E12.5)
    902 FORMAT(I5,2X,3F20.8,3I5)
    903 FORMAT(3E12.5,2I5)
    904 FORMAT(I5,2X,F20.8,10I5)
    905 FORMAT(I5)
    906 FORMAT(5E12.5)
    941 FORMAT(2I5,3F20.8,I5)
    942 FORMAT(3E12.5,2I5)
    943 FORMAT(3E12.5,2I5)
    944 FORMAT(I5,2X,F20.8,10I5)
   9440 FORMAT(4F20.8)
    945 FORMAT(I5)
    946 FORMAT(4E17.9)
   9946 FORMAT(3E17.9,I5)
   9941 FORMAT(2I5,'    !',3I5,3X,A3)
  JSWASP=0
  RETURN
END

