! ----------------------------------------------------------------------
!   This file is a part of EFDC+
!   Website:  https://eemodelingsystem.com/
!   Repository: https://github.com/dsi-llc/EFDC_Plus.git
! ----------------------------------------------------------------------
! Copyright 2021-2022 DSI, LLC
! Distributed under the GNU GPLv2 License.
! ----------------------------------------------------------------------
SUBROUTINE MASS_BALANCE

  ! *** Calculates sediment mass balance in the modeling domain
  ! *** PMC - This routine has not been updated from the original SNL code and
  ! ***       does not work in general cases!  Placeholder only...
  ! *** ***************************************************************************!
  USE GLOBAL
  
  INTEGER  L,K,KK,IICOUNZ1,IICOUNZ2,IICOUNZ3,IICOUNZ4,IICOUNZ5,IICOUNZ6
  REAL(RKD)  FLUXBEDLOAD,FLUXSUSLOAD,FLUXTOTLOAD,TOTALMASS,TOTALMASSB, &
             TOTALMASSS,TVOL1,TVOL2,TVOL3,TVOL4,TVOL5,TVOL6,AVGPER(6,NSED,KB)
  REAL(RKD)  TSEDMASS,TSEDMASS1,TSEDMASS2,TSEDMASS3,TSEDMASS4,TSEDMASS5,TSEDMASS6,THICKTOT,THICKAREA
  REAL(RKD)  TSED0MASS1,TSED0MASS2,TSED0MASS3,TSED0MASS4,TSED0MASS5,TSED0MASS6
  REAL(RKD)  DTTS,DIFFSED1,DIFFSED2

  REAL(RKD), SAVE ::TSED0MASS
  REAL(RKD), SAVE ::TOTALMASSI
  REAL(RKD), SAVE ::TOTALMASSOUT
      
  REAL(RKD), SAVE,ALLOCATABLE,DIMENSION(:)   :: THICKK        !(LCM)
  REAL(RKD), SAVE,ALLOCATABLE,DIMENSION(:)   :: TSEDTALL 
  REAL(RKD), SAVE,ALLOCATABLE,DIMENSION(:)   :: TSED0TALL 
  REAL(RKD), SAVE,ALLOCATABLE,DIMENSION(:,:) :: TSED0T 
  REAL(RKD), SAVE,ALLOCATABLE,DIMENSION(:,:) :: TSEDTT        !(LCM),TOXFTMP,TOXXTMP
  REAL(RKD), SAVE,ALLOCATABLE,DIMENSION(:)   :: TVOL
      
  IF( .NOT. ALLOCATED(THICKK) )THEN
    ALLOCATE(THICKK(LCM)) 
    ALLOCATE(TSEDTALL(LCM)) 
    ALLOCATE(TSED0TALL(LCM)) 
    ALLOCATE(TSED0T(LCM,9)) 
    ALLOCATE(TSEDTT(LCM,6))
    ALLOCATE(TVOL(LCM)) 

    THICKK = 0.0
    TSEDTALL = 0.0
    TSED0TALL = 0.0
    TSED0T = 0.0
    TSEDTT = 0.0
    TVOL = 0.0
    TSED0MASS = 0.0
    TOTALMASSI = 0.0
    TOTALMASSOUT = 0.0
  ENDIF
      
  FLUXBEDLOAD = 0.0E0
  FLUXSUSLOAD = 0.0E0
  FLUXTOTLOAD = 0.0E0
  TOTALMASS = 0.0E0
  TOTALMASSB = 0.0E0
  TOTALMASSS = 0.0E0
  TSEDMASS = 0.0E0
  TSEDMASS1 = 0.0E0
  TSEDMASS2 = 0.0E0
  TSEDMASS3 = 0.0E0
  TSEDMASS4 = 0.0E0
  TSEDMASS5 = 0.0E0
  TSEDMASS6 = 0.0E0
  IF( N == 1 )THEN  !ISEDTIME )THEN
    NDYCOUNT = 0
    TOTALMASSOUT = 0.0E0
    TSED0MASS = 0.0E0
    TSED0MASS1 = 0.0E0
    TSED0MASS2 = 0.0E0
    TSED0MASS3 = 0.0E0
    TSED0MASS4 = 0.0E0
    TSED0MASS5 = 0.0E0
    TSED0MASS6 = 0.0E0
    OPEN(213,FILE=OUTDIR//'MASS_BALANCE.DAT',STATUS='UNKNOWN')
    OPEN(214,FILE=OUTDIR//'SED_VOL-MASS_AREA.DAT',STATUS='UNKNOWN')
    OPEN(221,FILE=OUTDIR//'SED_THICK-MASS_1.DAT',STATUS='UNKNOWN')
    OPEN(222,FILE=OUTDIR//'SED_THICK-MASS_2.DAT',STATUS='UNKNOWN')
    OPEN(223,FILE=OUTDIR//'SED_THICK-MASS_3.DAT',STATUS='UNKNOWN')
    OPEN(224,FILE=OUTDIR//'SED_THICK-MASS_4.DAT',STATUS='UNKNOWN')
    OPEN(225,FILE=OUTDIR//'SED_THICK-MASS_5.DAT',STATUS='UNKNOWN')
    OPEN(226,FILE=OUTDIR//'SED_THICK-MASS_6.DAT',STATUS='UNKNOWN')
    OPEN(231,FILE=OUTDIR//'SED_THICK_1.DAT',STATUS='UNKNOWN')
    OPEN(232,FILE=OUTDIR//'SED_THICK_2.DAT',STATUS='UNKNOWN')
    OPEN(233,FILE=OUTDIR//'SED_THICK_3.DAT',STATUS='UNKNOWN')
    OPEN(234,FILE=OUTDIR//'SED_THICK_4.DAT',STATUS='UNKNOWN')
    OPEN(235,FILE=OUTDIR//'SED_THICK_5.DAT',STATUS='UNKNOWN')
    OPEN(236,FILE=OUTDIR//'SED_THICK_6.DAT',STATUS='UNKNOWN')
    OPEN(241,FILE=OUTDIR//'SED_PERCENT_1.DAT',STATUS='UNKNOWN')
    OPEN(242,FILE=OUTDIR//'SED_PERCENT_2.DAT',STATUS='UNKNOWN')
    OPEN(243,FILE=OUTDIR//'SED_PERCENT_3.DAT',STATUS='UNKNOWN')
    OPEN(244,FILE=OUTDIR//'SED_PERCENT_4.DAT',STATUS='UNKNOWN')
    OPEN(245,FILE=OUTDIR//'SED_PERCENT_5.DAT',STATUS='UNKNOWN')
    OPEN(246,FILE=OUTDIR//'SED_PERCENT_6.DAT',STATUS='UNKNOWN')
    OPEN(815,FILE=OUTDIR//'DEP_VOL.DAT',ACCESS='SEQUENTIAL',FORM='UNFORMATTED')
    
    DTTS = DTSEDJ
    WRITE(815)LA-1,DTTS
    WRITE(815)IL(2:LA)
    WRITE(815)JL(2:LA)
  ENDIF
  
  ! *** Sum total sediment mass in the bedload and water column
  DO L=2,LA
    TSEDTALL(L) = 0.0E0
    DO K=1,NSED
      TOTALMASSB = TOTALMASSB + CBL(L,K)*DXYP(L)*1.0E04
      DO KK=1,KC-2
        TOTALMASSS = TOTALMASSS + (SED(L,KK,K)*1.0E-6)*(DZC(L,KK)*HP(L)*100.0)*DXYP(L)*1.0E04
      ENDDO
      TOTALMASS = TOTALMASS+TOTALMASSB+TOTALMASSS
    ENDDO
  ENDDO

  ! *** Determine initial sediment thickness and mass of sediment
  IF( N == 1  )THEN  !ISEDTIME  )THEN 
    TOTALMASSI = TOTALMASS
    IF( IHTSTRT == 0  )THEN
      ! *** Cold start IC's
      DO L=2,LA
        TSED0TALL(L) = 0.0D0
        DO K=1,6
          TSED0T(L,K) = 0.0D0
        ENDDO
        DO K=3,KB
          TSED0TALL(L) = TSED0TALL(L)+TSED0(K,L)/BULKDENS(K,L)
        ENDDO
      ENDDO
      DO L=2,LA
        DO K=3,KB
          TSED0MASS = TSED0MASS+TSED0(K,L)*DXYP(L)*1.0D04
        ENDDO
        IF(NCORENO(IL(L),JL(L)) == 1 )THEN
          DO K=3,KB
            TSED0T(L,1) = TSED0T(L,1)+TSED0(K,L)/BULKDENS(K,L)
            TSED0MASS1 = TSED0MASS1+TSED0(K,L)*DXYP(L)*1.0D04
          ENDDO
        ENDIF
        IF(NCORENO(IL(L),JL(L)) == 2)THEN
          DO K=3,KB
            TSED0T(L,2) = TSED0T(L,2)+TSED0(K,L)/BULKDENS(K,L)
            TSED0MASS2 = TSED0MASS2+TSED0(K,L)*DXYP(L)*1.0E04
          ENDDO
        ENDIF
        IF(NCORENO(IL(L),JL(L)) == 3)THEN
          DO K=3,KB
            TSED0T(L,3) = TSED0T(L,3)+TSED0(K,L)/BULKDENS(K,L)
            TSED0MASS3 = TSED0MASS3+TSED0(K,L)*DXYP(L)*1.0E04
          ENDDO
        ENDIF
        IF(NCORENO(IL(L),JL(L)) == 4)THEN
          DO K=3,KB
            TSED0T(L,4) = TSED0T(L,4)+TSED0(K,L)/BULKDENS(K,L)
            TSED0MASS4 = TSED0MASS4+TSED0(K,L)*DXYP(L)*1.0E04
          ENDDO
        ENDIF
        IF(NCORENO(IL(L),JL(L)) == 5)THEN
          DO K=3,KB
            TSED0T(L,5) = TSED0T(L,5)+TSED0(K,L)/BULKDENS(K,L)
            TSED0MASS5 = TSED0MASS5+TSED0(K,L)*DXYP(L)*1.0E04
          ENDDO
        ENDIF
        IF(NCORENO(IL(L),JL(L)) == 6)THEN
          DO K=3,KB
            TSED0T(L,6) = TSED0T(L,6)+TSED0(K,L)/BULKDENS(K,L)
            TSED0MASS5 = TSED0MASS5+TSED0(K,L)*DXYP(L)*1.0E04
          ENDDO
        ENDIF
      ENDDO
    ELSE
      ! *** Hot start IC's
      DO L=2,LA
        TSED0TALL(L) = 0.0D0
        DO K=1,6
          TSED0T(L,K) = 0.0D0
        ENDDO
        DO K=3,KB
          TSED0TALL(L) = TSED0TALL(L)+TSED(K,L)/BULKDENS(K,L)
        ENDDO
      ENDDO
      DO L=2,LA
        DO K=3,KB
          TSED0MASS = TSED0MASS+TSED(K,L)*DXYP(L)*1.0D04
        ENDDO
        IF(NCORENO(IL(L),JL(L)) == 1 )THEN
          DO K=3,KB
            TSED0T(L,1) = TSED0T(L,1)+TSED(K,L)/BULKDENS(K,L)
            TSED0MASS1 = TSED0MASS1+TSED(K,L)*DXYP(L)*1.0D04
          ENDDO
        ENDIF
        IF(NCORENO(IL(L),JL(L)) == 2)THEN
          DO K=3,KB
            TSED0T(L,2) = TSED0T(L,2)+TSED(K,L)/BULKDENS(K,L)
            TSED0MASS2 = TSED0MASS2+TSED(K,L)*DXYP(L)*1.0E04
          ENDDO
        ENDIF
        IF(NCORENO(IL(L),JL(L)) == 3)THEN
          DO K=3,KB
            TSED0T(L,3) = TSED0T(L,3)+TSED(K,L)/BULKDENS(K,L)
            TSED0MASS3 = TSED0MASS3+TSED(K,L)*DXYP(L)*1.0E04
          ENDDO
        ENDIF
        IF(NCORENO(IL(L),JL(L)) == 4)THEN
          DO K=3,KB
            TSED0T(L,4) = TSED0T(L,4)+TSED(K,L)/BULKDENS(K,L)
            TSED0MASS4 = TSED0MASS4+TSED(K,L)*DXYP(L)*1.0E04
          ENDDO
        ENDIF
        IF(NCORENO(IL(L),JL(L)) == 5)THEN
          DO K=3,KB
            TSED0T(L,5) = TSED0T(L,5)+TSED(K,L)/BULKDENS(K,L)
            TSED0MASS5 = TSED0MASS5+TSED(K,L)*DXYP(L)*1.0E04
          ENDDO
        ENDIF
        IF(NCORENO(IL(L),JL(L)) == 6)THEN
          DO K=3,KB
            TSED0T(L,6) = TSED0T(L,6)+TSED(K,L)/BULKDENS(K,L)
            TSED0MASS5 = TSED0MASS5+TSED(K,L)*DXYP(L)*1.0E04
          ENDDO
        ENDIF
      ENDDO
    END IF
  ENDIF

  ! *** Calculate bed thickness and net change in bed mass (THICKTOT)
  THICKTOT = 0.0E0
  THICKAREA = 0.0E0
  TVOL1 = 0.0E0
  TVOL2 = 0.0E0
  TVOL3 = 0.0E0
  TVOL4 = 0.0E0
  TVOL5 = 0.0E0
  TVOL6 = 0.0E0
  DO L=1,3
    DO KK=1,NSED
      DO K=1,KB
        AVGPER(L,KK,K) = 0.0
      ENDDO
    ENDDO
  ENDDO
  IICOUNZ1 = 0
  IICOUNZ2 = 0
  IICOUNZ3 = 0
  IICOUNZ4 = 0
  IICOUNZ5 = 0
  IICOUNZ6 = 0
  DO L=2,LA
    DO K=1,KB
      TSEDMASS = TSEDMASS+TSED(K,L)*DXYP(L)*1.0E04
    ENDDO
    DO K=1,KB
      TSEDTALL(L) = TSEDTALL(L)+TSED(K,L)/BULKDENS(K,L)
    ENDDO
    IF(NCORENO(IL(L),JL(L)) == 1 )THEN
      IICOUNZ1 = IICOUNZ1+1
      TSEDTT(L,1) = 0.0E0
      DO K=1,KB
        TSEDTT(L,1) = TSEDTT(L,1)+TSED(K,L)/BULKDENS(K,L)
        TSEDMASS1 = TSEDMASS1+TSED(K,L)*DXYP(L)*1.0E04
        DO KK=1,NSED
          AVGPER(1,KK,K) = AVGPER(1,KK,K)+PERSED(KK,K,L)
        ENDDO            
      ENDDO
      THICKK(L) = TSEDTT(L,1)-TSED0T(L,1)
      THICKAREA = THICKAREA+DXYP(L)*1.0E04
      THICKTOT = THICKTOT+THICKK(L)*DXYP(L)*1.0E04
      TVOL1 = TVOL1+TSEDTT(L,1)*DXYP(L)*1.0E04
    ENDIF
    IF(NCORENO(IL(L),JL(L)) == 2)THEN
      IICOUNZ2 = IICOUNZ2+1
      TSEDTT(L,2) = 0.0E0
      DO K=1,KB
        TSEDTT(L,2) = TSEDTT(L,2)+TSED(K,L)/BULKDENS(K,L)
        TSEDMASS2 = TSEDMASS2+TSED(K,L)*DXYP(L)*1.0E04
        DO KK=1,NSED
          AVGPER(2,KK,K) = AVGPER(2,KK,K)+PERSED(KK,K,L)
        ENDDO            
      ENDDO
      THICKK(L) = TSEDTT(L,2)-TSED0T(L,2)
      THICKAREA = THICKAREA+DXYP(L)*1.0E04
      THICKTOT = THICKTOT+THICKK(L)*DXYP(L)*1.0E04
      TVOL2 = TVOL2+TSEDTT(L,2)*DXYP(L)*1.0E04
    ENDIF
    IF(NCORENO(IL(L),JL(L)) == 3)THEN
      IICOUNZ3 = IICOUNZ3+1
      TSEDTT(L,3) = 0.0E0
      DO K=1,KB
        TSEDTT(L,3) = TSEDTT(L,3)+TSED(K,L)/BULKDENS(K,L)
        TSEDMASS3 = TSEDMASS3+TSED(K,L)*DXYP(L)*1.0E04
        DO KK=1,NSED
          AVGPER(3,KK,K) = AVGPER(3,KK,K)+PERSED(KK,K,L)
        ENDDO
      ENDDO
      THICKK(L) = TSEDTT(L,3)-TSED0T(L,3)
      THICKAREA = THICKAREA+DXYP(L)*1.0E04
      THICKTOT = THICKTOT+THICKK(L)*DXYP(L)*1.0E04
      TVOL3 = TVOL3+TSEDTT(L,3)*DXYP(L)*1.0E04
    ENDIF
    IF(NCORENO(IL(L),JL(L)) == 4)THEN
      IICOUNZ4 = IICOUNZ4+1
      TSEDTT(L,4) = 0.0E0
      DO K=1,KB
        TSEDTT(L,4) = TSEDTT(L,4)+TSED(K,L)/BULKDENS(K,L)
        TSEDMASS3 = TSEDMASS3+TSED(K,L)*DXYP(L)*1.0E04
        DO KK=1,NSED
          AVGPER(4,KK,K) = AVGPER(4,KK,K)+PERSED(KK,K,L)
        ENDDO
      ENDDO
      THICKK(L) = TSEDTT(L,4)-TSED0T(L,4)
      THICKAREA = THICKAREA+DXYP(L)*1.0E04
      THICKTOT = THICKTOT+THICKK(L)*DXYP(L)*1.0E04
      TVOL4 = TVOL4+TSEDTT(L,4)*DXYP(L)*1.0E04
    ENDIF
    IF(NCORENO(IL(L),JL(L)) == 5)THEN
      IICOUNZ5 = IICOUNZ5+1
      TSEDTT(L,5) = 0.0E0
      DO K=1,KB
        TSEDTT(L,5) = TSEDTT(L,5)+TSED(K,L)/BULKDENS(K,L)
        TSEDMASS5 = TSEDMASS5+TSED(K,L)*DXYP(L)*1.0E04
        DO KK=1,NSED
          AVGPER(5,KK,K) = AVGPER(5,KK,K)+PERSED(KK,K,L)
        ENDDO
      ENDDO
      THICKK(L) = TSEDTT(L,5)-TSED0T(L,5)
      THICKAREA = THICKAREA+DXYP(L)*1.0E04
      THICKTOT = THICKTOT+THICKK(L)*DXYP(L)*1.0E04
      TVOL5 = TVOL5+TSEDTT(L,5)*DXYP(L)*1.0E04
    ENDIF
    IF(NCORENO(IL(L),JL(L)) == 6)THEN
      IICOUNZ5 = IICOUNZ5+1
      TSEDTT(L,6) = 0.0E0
      DO K=1,KB
        TSEDTT(L,6) = TSEDTT(L,6)+TSED(K,L)/BULKDENS(K,L)
        TSEDMASS5 = TSEDMASS5+TSED(K,L)*DXYP(L)*1.0E04
        DO KK=1,NSED
          AVGPER(6,KK,K) = AVGPER(6,KK,K)+PERSED(KK,K,L)
        ENDDO
      ENDDO
      THICKK(L) = TSEDTT(L,6)-TSED0T(L,6)
      THICKAREA = THICKAREA+DXYP(L)*1.0E04
      THICKTOT = THICKTOT+THICKK(L)*DXYP(L)*1.0E04
      TVOL5 = TVOL5+TSEDTT(L,6)*DXYP(L)*1.0E04
    ENDIF
    TVOL(L) = (TSEDTALL(L)-TSED0TALL(L))*DXYP(L)*1.0D-2
  ENDDO

  THICKTOT = THICKTOT/THICKAREA
  DIFFSED1 = TSED0MASS+TOTALMASSI
  DIFFSED2 = TSEDMASS+TOTALMASS

  ! *** Write bed conditions
  WRITE(815)N
  WRITE(815)TVOL(2:LA)
  FLUSH(815)
  DO L=2,LA
    TSEDMASS1 = 0.0E0
    TSEDMASS2 = 0.0E0
    TSEDMASS3 = 0.0E0
    TSEDMASS4 = 0.0E0
    TSEDMASS5 = 0.0E0
    TSEDMASS6 = 0.0E0
    IF(NCORENO(IL(L),JL(L)) == 1 )THEN
      TSEDTT(L,1) = 0.0E0
      DO K=1,KB
        WRITE(241,98775) NITER, L,K,(PERSED(KK,K,L),KK=1,NSED)
      ENDDO
      DO K=1,KB
        TSEDTT(L,1) = TSEDTT(L,1)+TSED(K,L)/BULKDENS(K,L)
        TSEDMASS1 = TSEDMASS1+TSED(K,L)*DXYP(L)*1.0E04
      ENDDO
      WRITE(221,10001) NITER, L,NCORENO(IL(L),JL(L)),TSEDTT(L,1),TSEDMASS1
    ENDIF
    IF(NCORENO(IL(L),JL(L)) == 2)THEN
      TSEDTT(L,2) = 0.0E0
      DO K=1,KB
        WRITE(242,98775) NITER, L,K,(PERSED(KK,K,L),KK=1,NSED)
      ENDDO
      DO K=1,KB
        TSEDTT(L,2) = TSEDTT(L,2)+TSED(K,L)/BULKDENS(K,L)
        TSEDMASS2 = TSEDMASS2+TSED(K,L)*DXYP(L)*1.0E04
      ENDDO
      WRITE(222,10001) NITER, L,NCORENO(IL(L),JL(L)),TSEDTT(L,2),TSEDMASS2
    ENDIF
    IF(NCORENO(IL(L),JL(L)) == 3)THEN
      TSEDTT(L,3) = 0.0E0
      DO K=1,KB
        WRITE(243,98775) NITER, L,K,(PERSED(KK,K,L),KK=1,NSED)
      ENDDO
      DO K=1,KB
        TSEDTT(L,3) = TSEDTT(L,3)+TSED(K,L)/BULKDENS(K,L)
        TSEDMASS3 = TSEDMASS3+TSED(K,L)*DXYP(L)*1.0E04
      ENDDO
      WRITE(223,10001) NITER, L,NCORENO(IL(L),JL(L)),TSEDTT(L,3),TSEDMASS3
    ENDIF
    IF(NCORENO(IL(L),JL(L)) == 4)THEN
      TSEDTT(L,4) = 0.0E0
      DO K=1,KB
        WRITE(244,98775) NITER, L,K,(PERSED(KK,K,L),KK=1,NSED)
      ENDDO
      DO K=1,KB
        TSEDTT(L,4) = TSEDTT(L,4)+TSED(K,L)/BULKDENS(K,L)
        TSEDMASS4 = TSEDMASS4+TSED(K,L)*DXYP(L)*1.0E04
      ENDDO
      WRITE(224,10001) NITER, L,NCORENO(IL(L),JL(L)),TSEDTT(L,4),TSEDMASS4
    ENDIF
    IF(NCORENO(IL(L),JL(L)) == 5)THEN
      TSEDTT(L,5) = 0.0E0
      DO K=1,KB
        WRITE(245,98775) NITER, L,K,(PERSED(KK,K,L),KK=1,NSED)
      ENDDO
      DO K=1,KB
        TSEDTT(L,5) = TSEDTT(L,5)+TSED(K,L)/BULKDENS(K,L)
        TSEDMASS5 = TSEDMASS5+TSED(K,L)*DXYP(L)*1.0E04
      ENDDO
      WRITE(225,10001) NITER, L,NCORENO(IL(L),JL(L)),TSEDTT(L,5),TSEDMASS5
    ENDIF
    IF(NCORENO(IL(L),JL(L)) == 6)THEN
      TSEDTT(L,6) = 0.0E0
      DO K=1,KB
        WRITE(246,98775) NITER, L,K,(PERSED(KK,K,L),KK=1,NSED)
      ENDDO
      DO K=1,KB
        TSEDTT(L,6) = TSEDTT(L,6)+TSED(K,L)/BULKDENS(K,L)
        TSEDMASS5 = TSEDMASS5+TSED(K,L)*DXYP(L)*1.0E04
      ENDDO
      WRITE(226,10001) NITER, L,NCORENO(IL(L),JL(L)),TSEDTT(L,6),TSEDMASS5
    ENDIF
  ENDDO
  
  NDYCOUNT = 0
  
10001 FORMAT(I9,2I6,2(E17.10))
10002 FORMAT(I12,I6,E15.7)
98775 FORMAT(' N,K,L,PERSED(KK=1,NSED,K=1,KB) =',I12,2I7,9F10.6)

   FLUSH(213)
   FLUSH(214)
   FLUSH(221)
   FLUSH(222)
   FLUSH(223)
   FLUSH(224)
   FLUSH(225)
   FLUSH(226)
   FLUSH(231)
   FLUSH(232)
   FLUSH(233)
   FLUSH(234)
   FLUSH(235)
   FLUSH(236)
   FLUSH(241)
   FLUSH(242)
   FLUSH(243)
   FLUSH(244)
   FLUSH(245)
   FLUSH(246)
  
  RETURN
END
