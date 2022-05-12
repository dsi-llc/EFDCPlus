! ----------------------------------------------------------------------
!   This file is a part of EFDC+
!   Website:  https://eemodelingsystem.com/
!   Repository: https://github.com/dsi-llc/EFDC_Plus.git
! ----------------------------------------------------------------------
! Copyright 2021-2022 DSI, LLC
! Distributed under the GNU GPLv2 License.
! ----------------------------------------------------------------------
SUBROUTINE SHOWVAL

  ! *** REWRITTEN BY PAUL M. CRAIG  ON DEC 2006
  ! ***
  ! *** 2010_06 CHANGED THE NSHTYPE TO CORRESPOND TO PARAMETER LIST
       
  USE GLOBAL
  Use Variables_WQ
  
  Use Variables_MPI
  USE INFOMOD,ONLY:SKIPCOM,READSTR

  IMPLICIT NONE

  INTEGER :: ISREAD,NSKIP,JSHPRT,INFODT,L,LN,IZSURF,IVELEKC,IVELNKC,IAVKS,IABKS
  INTEGER :: IVELEKB,IVELNKB,IAVKB,IABKB,ICKC,ICKB,NINFO,IQLO(0:5),IQHI(0:5)
  INTEGER :: I, K, NWQ, LQ, LL, NOPEN
  INTEGER, STATIC :: IPARAM,ISUB

  REAL :: TIME,ZSURF,UTMP,VTMP,VELEKC,VELNKC,VELEKB,VELNKB,AVKS,AVKB,ABKS,ABKB,CKC,CKB
  REAL :: T1,T2,TSPEED,ETA,QOUT,QIN,QOPEN,ETIME

  CHARACTER UNITS*3, PARM*4, CSUB*1
  CHARACTER*80 STR*200
   
  SAVE      INFODT, JSHPRT, UNITS, PARM, NINFO

  REAL(RKD),EXTERNAL :: DSTIME 

  DATA ISREAD/0/
  DATA UNITS/'PPM'/
  
  Integer :: ICSHOW_DUM
  Integer :: JCSHOW_DUM
  Integer :: i_tmp, j_tmp
  Logical :: show_val_inside
  
  IF( ISDYNSTP == 0 )THEN  
    DELT=DT  
  ELSE  
    DELT=DTDYN  
  END IF  

  IF( ISREAD == 0 )THEN
    ISREAD=1
    OPEN(1,FILE='show.inp',STATUS='OLD')
    STR=READSTR(1)  ! *** SKIP OVER TITLE AND AND HEADER LINES 
    READ(1,*)NSHTYPE,NSHOWR,ICSHOW_DUM,JCSHOW_DUM,ISHPRT
    
    ICSHOW = IG2IL(ICSHOW_DUM) !*** Remapping for domain decomposition
    JCSHOW = JG2JL(JCSHOW_DUM) !*** Remapping for domain decomposition
    
    READ(1,*)ZSSMIN,ZSSMAX,SSALMAX
    CLOSE(1)
    NSHOWR=20
    NSHOWC=NSHOWR
    IF( ISHPRT < 1)ISHPRT=1
    JSHPRT=ISHPRT
    NINFO = -1
    
    ! *** SET THE DISPLAY PARAMETER
    IF( NSHTYPE < 10 )THEN
      IPARAM=NSHTYPE
      ISUB=0
      CSUB='0'
    ELSE
      IPARAM=NSHTYPE/100
      ISUB= MOD(INT(NSHTYPE,4),100)
      IF( ISUB < 10)WRITE(CSUB,'(I1)')ISUB
    ENDIF

    UNITS='PPM'
    IF( IPARAM == 1 )THEN
      ! *** SALINITY
      UNITS='PPT'
      PARM='SAL'
    ELSEIF( IPARAM == 2 )THEN
      ! *** TEMPERATURE
      UNITS='D:C'
      PARM='TEM'
    ELSEIF( IPARAM == 3 )THEN
      ! *** DYE
      PARM='DYE'
    ELSEIF( IPARAM == 5 )THEN
      ! *** TOXICS
      UNITS='PPB'
      IF( ISUB > 0 .AND. ISUB <= NTOX )THEN
        PARM='TX' // CSUB
      ELSE
        PARM='TOX'
      ENDIF
    ELSEIF( IPARAM == 6 )THEN
      ! *** COHESIVES
      IF( ISUB > 0 .AND. ISUB <= NSED )THEN
        PARM='SD' // CSUB
      ELSE
        PARM='SED'
      ENDIF
    ELSEIF( IPARAM == 7 )THEN
      ! *** NON-COHESIVES
      IF( ISUB > 0 .AND. ISUB <= NSND )THEN
        PARM='SN' // CSUB
      ELSE
        PARM='SND'
      ENDIF

    ELSEIF( IPARAM == 0 )THEN
      ! *** TSS
      PARM='TSS'

    ELSEIF( IPARAM == 8 )THEN
      ! *** WATER QUALITY
      IF( ISUB < 1 .OR. ISUB > NWQV ) ISUB = IDOX  ! *** DEFAULT TO D.O.
      PARM = WQCONSTIT(ISUB)

    ENDIF

  ENDIF

  NITERAT = NITERAT + 1
  
  ! *** SETUP THE VARIABLES
  show_val_inside = .FALSE.
  i_tmp = IG2IL(ICSHOW)
  j_tmp = JG2JL(JCSHOW)
  ! *** Check if the cell to show is in the current domain
  if(i_tmp > 0 .and. i_tmp < IC )THEN
    if(j_tmp > 0 .and. j_tmp < JC )THEN
      show_val_inside = .TRUE.
      L=LIJ(i_tmp,j_tmp)
    endif
  endif
  ! *** Set L to a value that definitely will be inside so that we don't index arrays outside of domain
  if(show_val_inside == .FALSE.)then  ! *** L is outside of domain
    L = 10
  endif
  
  IF( ISDYNSTP == 0 )THEN
    TIME=(DT*FLOAT(N)+TCON*TBEGIN)/86400.
  ELSE
    TIME=TIMESEC/86400.
  ENDIF

  
  ! *** DISPLAY THE HEADER
  IF( NSHOWC >= NSHOWR )THEN
    NSHOWC=0
    NINFO = NINFO + 1
    
    IF( ISDYNSTP > 0 )THEN
      INFODT=INFODT+1
      IF( INFODT > 10 .OR. NITERAT == 1 )THEN
        IF( DTSSDHDT > 0. )THEN
          WRITE(6,9000) DTL1MN,L1LOC,DTL2MN,L2LOC,DTL3MN,L3LOC,DTL4MN,L4LOC
        ELSE
          WRITE(6,9000) DTL1MN,L1LOC,DTL2MN,L2LOC,DTL3MN,L3LOC
        ENDIF
        WRITE(6,*)' '
        INFODT=0
      ENDIF
    ENDIF
    
    ! *** MODEL DETAILS
    IF( NINFO == 0 .OR. NINFO == 10 )THEN
      NINFO = 0
      
      QOUT = 0.
      QIN  = 0.
      DO LQ=2,LA
        IF( QSUME(LQ) < 0. )THEN
          QOUT = QOUT - QSUME(LQ)
        ELSE
          QIN  = QIN  + QSUME(LQ)
        ENDIF
      ENDDO

      IQLO(1) = QOUT
      IQHI(1) = QIN
      
      ! **  ACCUMULATE FLUXES ACROSS OPEN BOUNDARIES
      QOUT = 0.
      QIN  = 0.
      DO K=1,KC
        DO LL=1,NPBS
          LQ=LPBS(LL)
          LN=LNC(LQ)
          QOPEN = VHDX2(LN,K)
          IF( QOPEN < 0. )THEN
            QOUT = QOUT + ABS(QOPEN)
          ELSE
            QIN  = QIN  + ABS(QOPEN)
          ENDIF
        ENDDO
      ENDDO
      IQLO(2) = QOUT
      IQHI(2) = QIN
  
      QOUT = 0.
      QIN  = 0.
      DO K=1,KC
        DO LL=1,NPBW
          LQ=LPBW(LL)
          QOPEN = UHDY2(LQ+1,K)
          IF( QOPEN < 0. )THEN
            QOUT = QOUT + ABS(QOPEN)
          ELSE
            QIN  = QIN  + ABS(QOPEN)
          ENDIF
        ENDDO
      ENDDO
      IQLO(3) = QOUT
      IQHI(3) = QIN
      
      QOUT = 0.
      QIN  = 0.
      DO K=1,KC
        DO LL=1,NPBE
          LQ=LPBE(LL)
          QOPEN = UHDY2(LQ,K)
          IF( QOPEN > 0. )THEN
            QOUT = QOUT + ABS(QOPEN)
          ELSE
            QIN  = QIN  + ABS(QOPEN)
          ENDIF
        ENDDO
      ENDDO
      IQLO(4) = QOUT
      IQHI(4) = QIN
  
      QOUT = 0.
      QIN  = 0.
      DO K=1,KC
        DO LL=1,NPBN
          LQ=LPBN(LL)
          QOPEN = VHDX2(LQ,K)
          IF( QOPEN > 0. )THEN
            QOUT = QOUT + ABS(QOPEN)
          ELSE
            QIN  = QIN  + ABS(QOPEN)
          ENDIF
        ENDDO
      ENDDO
      IQLO(5) = QOUT
      IQHI(5) = QIN
      IQLO(0) = SUM(IQLO(1:5))
      IQHI(0) = SUM(IQHI(1:5))
      
      IF( NWSER > 0 )THEN
        UTMP = ATAN2(WNDVELE(L),WNDVELN(L))/PI*180.
        IF( UTMP < 0. )UTMP = UTMP+360.
      ELSE
        UTMP = 0.
      ENDIF
      IF( SVPAT(L) > 0. )THEN
        VTMP = VPAT(L)/SVPAT(L)*100.
      ELSE
        VTMP = 0.
      ENDIF
      IF( ISICE > 0 )THEN
        CKC = ICETHICK(L)*100.
      ELSE
        CKC = 0.
      ENDIF
      
      WRITE(*,'(/)')
      WRITE(*,'(A)')'    TIME WSPEED DIRTO  TAIR  RELH  SOLR  RAIN  EVAP ICETH    INFLOW   OUTFLOW'
      WRITE(*,'(A)')'    DAYS    M/S   DEG     C   PER  W/M2  MM/D  MM/D    CM      M3/S      M3/S'
      WRITE(*,'(A)')'-------------------------------------------------------------------------------'
      WRITE(*,9300) TIME, INT(WINDST(L),4), INT(UTMP,4), INT(TATMT(L)+.5,4),INT(VTMP,4), INT(SOLSWRT(L),4),  & 
                          INT(RAINT(L)*86400000.,4), INT(EVAPT(L)*86400000.,4), INT(CKC,4),IQHI(0),IQLO(0)
      NOPEN = NPBS+NPBW+NPBE+NPBN
      IF( NOPEN > 0 )THEN
        WRITE(*,9400)'OPEN: NORTH',IQHI(5),IQLO(5)
        WRITE(*,9400)'OPEN: EAST ',IQHI(4),IQLO(4)
        WRITE(*,9400)'OPEN: WEST ',IQHI(3),IQLO(3)
        WRITE(*,9400)'OPEN: SOUTH',IQHI(2),IQLO(2)
        WRITE(*,9401)'OTHER BCs  ',IQHI(1),IQLO(1)
      ELSE
        WRITE(*,9402)
      ENDIF
    ENDIF
    
    ! *** ESTIMATE TIME TO COMPLETION
    IF( N > 1 )THEN
      TCGRS = DSTIME(1)
      T1 = TBEGIN*TCON
      T2 = (TBEGIN*TCON+TIDALP*NTC)
      TSPEED = TCGRS/(TIMESEC-T1)
      ETA = (T2-TIMESEC)*TSPEED/3600.
      ETA = MIN(ETA,99999.989)
      T1 = TCGRS/3600.
      WRITE(*,'('' ** ELAPSED TIME: '',F8.2,'' (hr)   ESTIMATED TIME TO COMPLETION:'',F10.2,'' (hr)'')') T1,ETA
    ENDIF
        
    WRITE(*,'(A)')'--------------------------------------------------------------------------------'
    IF( ISDYNSTP > 0 )THEN
      WRITE(*,'(A)')'    TIME     TIME   ELEV VELE VELN  '//PARM//'   AV    AB  VELE  VELN  '//PARM//'   AV      '
      WRITE(*,'(A)')'     IN      STEP   SURF SURF SURF  SUR  SURF  SURF  BOTT  BOTT  BOTT  BOTT     '
      WRITE(*,'(A)')'    DAYS      SEC     CM CM/S CM/S  '//UNITS//'  CM/S  CM/S  CM/S  CM/S  '//UNITS//'  CM/S  LMIN'
    ELSE
      WRITE(*,'(A)')'    TIME     TIME   ELEV VELE VELN  '//PARM//'   AV    AB  VELE  VELN  '//PARM//'   AV    AB '
      WRITE(*,'(A)')'     IN      STEP   SURF SURF SURF  SUR  SURF  SURF  BOTT  BOTT  BOT  BOTT  BOTT'
      WRITE(*,'(A)')'    DAYS      SEC     CM CM/S CM/S  '//UNITS//'  CM/S  CM/S  CM/S  CM/S  '//UNITS//'  CM/S  CM/S'
    ENDIF
    WRITE(*,'(A)')'--------------------------------------------------------------------------------'
    ETIME = DT*N/86400.
    IF( LMHK .AND. ETIME > 0.01 )WRITE(*,'("SUPPORT ENERGY LOSS",F10.4," MW-hr")')SUM(ESUP(:,:))
    IF( LMHK .AND. ETIME > 0.01 )WRITE(*,'("MHK ENERGY OUTPUT  ",F10.4," MW-hr")')SUM(EMHK(:,:))
    IF( LMHK .AND. ETIME > 0.01 )WRITE(*,'("MHK POWER OUTPUT   ",F10.4," kW")')SUM(PMHK(:,:))*1E-3
    
  ENDIF

  ! *** INCREMENT THE SCREEN COUNTER
  JSHPRT = JSHPRT+1
  IF( JSHPRT < ISHPRT )RETURN
  
  ! *** INCREMENT THE SCREEN COUNTER
  JSHPRT=1
  NSHOWC = NSHOWC+1

  LN=LNC(L)
  ZSURF=(HP(L)+BELV(L))*100.
  UTMP=0.5*STCUV(L)*(U(LEC(L),KC)+U(L,KC))*100.
  VTMP=0.5*STCUV(L)*(V(LN,KC)+V(L,KC))*100.
  VELEKC=CUE(L)*UTMP+CVE(L)*VTMP

  
  VELNKC=CUN(L)*UTMP+CVN(L)*VTMP
  UTMP=0.5*STCUV(L)*(U(LEC(L),KSZ(L))+U(L,KSZ(L)))*100.
  VTMP=0.5*STCUV(L)*(V(LN,KSZ(L))+V(L,KSZ(L)))*100.
  VELEKB=CUE(L)*UTMP+CVE(L)*VTMP
  VELNKB=CUN(L)*UTMP+CVN(L)*VTMP
  AVKS=MIN(AV(L,KS)*10000.*HP(L),99999.)
  AVKB=MIN(AV(L,KSZ(L))*10000.*HP(L),99999.)
  ABKS=MIN(AB(L,KS)*10000.*HP(L),99999.)
  ABKB=MIN(AB(L,KSZ(L))*10000.*HP(L),99999.)

  IZSURF=NINT(ZSURF)
  IVELEKC=NINT(VELEKC)
  IVELNKC=NINT(VELNKC)
  IAVKS=NINT(AVKS)
  IABKS=NINT(ABKS)
  IVELEKB=NINT(VELEKB)
  IVELNKB=NINT(VELNKB)
  IAVKB=NINT(AVKB)
  IABKB=NINT(ABKB)
  
  ! *** CONTROL SIZE TO PREVENT FORMAT ERRORS
  IAVKS=MIN(IAVKS,99999)
  IABKS=MIN(IABKS,99999)
  IAVKB=MIN(IAVKB,99999)
  IABKB=MIN(IABKB,99999)

  ! *** CONSTITUENTS
  CKC=0.
  CKB=0.
  IF( IPARAM == 1 )THEN
    CKC=SAL(L,KC)
    CKB=SAL(L,KSZ(L))

  ELSEIF( IPARAM == 2 )THEN
    CKC=TEM(L,KC)
    CKB=TEM(L,KSZ(L))

  ELSEIF( IPARAM == 3 )THEN
    CKC=DYE(L,KC,1)
    CKB=DYE(L,KSZ(L),1)

  ELSEIF( IPARAM == 5 .AND. ISTRAN(5) > 0 )THEN
    IF( ISUB >0 .AND. ISUB <= NTOX )THEN
      CKC=TOX(L,KC,ISUB)
      CKB=TOX(L,KSZ(L),ISUB)
    ELSE
      CKC=0.
      DO I=1,NTOX
        CKC = CKC+TOX(L,KC,I)
      ENDDO
      CKB=0.
      DO I=1,NTOX
        CKB = CKB+TOX(L,KSZ(L),I)
      ENDDO
    ENDIF

  ELSEIF( IPARAM == 6 .AND. ISTRAN(6) > 0 )THEN
    IF( ISUB >0 .AND. ISUB <= NSED )THEN
      CKC=SED(L,KC,ISUB)
      CKB=SED(L,KSZ(L),ISUB)
    ELSE
      CKC=SEDT(L,KC)
      CKB=SEDT(L,KSZ(L))
    ENDIF

  ELSEIF( IPARAM == 7 .AND. ISTRAN(7) > 0 )THEN
    IF( ISUB >0 .AND. ISUB <= NSND )THEN
      CKC=SND(L,KC,ISUB)
      CKB=SND(L,KSZ(L),ISUB)
    ELSE
      CKC=SNDT(L,KC)
      CKB=SNDT(L,KSZ(L))
    ENDIF

  ELSEIF( IPARAM == 0 .AND. (ISTRAN(6) > 0 .OR. ISTRAN(7) > 0 ) )THEN
    CKC=(SEDT(L,KC)+SNDT(L,KC))
    CKB=(SEDT(L,KSZ(L))+SNDT(L,KSZ(L)))

  ELSEIF( IPARAM == 8 .AND. ISTRAN(8) > 0 )THEN
    CKC=WQV(L,KC,ISUB)
    CKB=WQV(L,KSZ(L),ISUB)

  ENDIF

  ICKC=MIN(NINT(CKC),99999)
  ICKB=MIN(NINT(CKB),99999)
  IF( ISDYNSTP > 0 )THEN
    WRITE(*,9100)TIME,DELT,IZSURF,IVELEKC,IVELNKC,ICKC,IAVKS,IABKS,IVELEKB,IVELNKB,ICKB,IAVKB,LMINSTEP
  ELSE
    WRITE(*,9100)TIME,DELT,IZSURF,IVELEKC,IVELNKC,ICKC,IAVKS,IABKS,IVELEKB,IVELNKB,ICKB,IAVKB,IABKB
  ENDIF

  RETURN

  9000 FORMAT(/' AUTOSTEPPING SUMMARY (WITH SAFETY FACTOR):',/       &
               '   METHOD1:    MOMENTUM CHECK (DT,L): ',F10.4,I5,/   &
               '   METHOD2:   ADVECTION CHECK (DT,L): ',F10.4,I5,/   &
               '   METHOD3:   BTM FRICT CHECK (DT,L): ',F10.4,I5,/,: &
               '   METHOD4: LIMIT DH/DT CHECK (DT,L): ',F10.4,I5,/)
  9100 FORMAT(F9.3,F8.3,I7,3I5,4I6,I5,2I6)
  9300 FORMAT(F9.3,8I6,2I10,/)
  9400 FORMAT(46X,A11,2I10)
  9401 FORMAT(46X,A11,2I10,//)
  9402 FORMAT(//)

END
