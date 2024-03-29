! ----------------------------------------------------------------------
!   This file is a part of EFDC+
!   Website:  https://eemodelingsystem.com/
!   Repository: https://github.com/dsi-llc/EFDC_Plus.git
! ----------------------------------------------------------------------
! Copyright 2021-2022 DSI, LLC
! Distributed under the GNU GPLv2 License.
! ----------------------------------------------------------------------
! @details SUBROUTINE CALTBXY CALCULATES BOTTOM FRICTION OR DRAG  
!! COEFFICIENTS IN QUADRATIC LAW FORM REFERENCED TO NEAR  
!! BOTTOM OR DEPTH AVERAGED HORIZONTAL VELOCITIES  
!! FOR VEGETATION RESISTANCE IN DEPTH INTEGRATED FLOW  
!! THE COEFFICIENT REPRESENTS BOTTOM AND WATER COLUMN VEGETATION  
!! RESISTANCE 

! @date  2019-06       PAUL M. CRAIG     CHANGED DRAG COEFFICIENT APPROACH FOR CONSISTENT TREATMENT OF LAYERS
!!                                      AND THIN BOTTOM LAYERS RELATIVE TO Z0
!!       2015-06       PAUL M. CRAIG     IMPLEMENTED SIGMA-Z (SGZ) IN EE7.3 
!!       2014-09       PAUL M. CRAIG     ADDED THE LWET BYPASS APPROACH
!!       2013-08-05    DANG CHUNG        Correction of drag coefficient for wave conditions
!!       2011-04-26    DANG CHUNG        Corrected Wave Formulation & Orbital Velocity
!!       2011-03-02    PAUL M. CRAIG     RESTRUCTURED AND CORRECTED CODE, ADDED OMP
!!       2011-01-15    PAUL M. CRAIG     ADDED THE FRACTIONAL SCALING FOR PARTIAL PENETRATION OF VEGETATION
!!       2010-XX-XX    SCOTT JAMES       ADDED MHK
!!       11/08/2001    john hamrick      REMOVED DRAG COEFFICIENT CONSTRAINT FOR MULIPLE LAYER ROUGHNESS
!!                                         BOUNDARIES WHEN DYNAMIC TIME STEPPING IS ACTIVE
!!       01/28/2002    john hamrick      FIXED POSSIBLE DIVIDE BY ZERO FOR SUB GRID CHANNEL FRICTION IN 
!!                                      ABSENCE OF VEGETATION RESISTANCE

SUBROUTINE CALTBXY

  USE GLOBAL  
  Use Variables_WQ
  
  Use MPI
  Use Variables_MPI 
  Use Communicate_Ghost_Routines
  
  IMPLICIT NONE

  INTEGER :: L, K, LS, M, LW, LE, LN, LNW, LSE, MW, MS, LF, LL, ND, LP, LG, IOBC
  INTEGER :: NMD, LHOST, LCHNU, LCHNV, MH, MU, MV, NTMP, LDMW, LWAVE, NAL, IERR

  REAL :: CDTOTUM, CDTOTVM, CDMAXUM, CDMAXVM
  REAL :: UMAGTMP, VMAGTMP, CDMAXU, CDMAXV, ZBRATUC, ZBRATVC
  REAL :: HURTMP, HVRTMP, HUDZBR, HVDZBR, VTMPATU, UTMPATV, CPVEGU
  REAL :: CPVEGV, HVGTC, HVGTW, HVGTS, VISEXP, VISFAC, VISMUDU
  REAL :: VISMUDV, SEDTMP, CSEDVIS, VISDHU, VISDHV, DZHUDZBR, DZHVDZBR
  REAL :: FRACLAY, FHLAYC, FHLAYW, FHLAYS, WCHAN, RLCHN, HCHAN, STBXCH
  REAL :: FXVEGCH, STBYCH, FYVEGCH, TMPVALW, WVFACT, QQWCTMP, TWCTMP
  REAL :: AEXTMP, TMPVAL, USTARC, CDRGTMP, TAUBTMP, TAUE, RIPAMP
  REAL :: RIPSTP, RIPFAC, ZBREU
  REAL :: WVDTMP, RKZTURB, UTMP, VTMP, DWVDZ, DWUDZ, DWVD2Z
  REAL :: DWUD2Z, HZRVDZ, HZRUDZ, ZDHZRV, ZDHZRU, ZBREV, HZREFV, HZREFU
  REAL :: QWDQCV, QWDQCU, QCTMPV, QCTMPU, CDTMPVY
  REAL :: BOTTMP, DWVDHR, DWUDHR, QWCTMPV, QWCTMPU
  REAL :: CDTMPV, CDTMPU, COSWC, CURANG, CDTMPUX
  REAL :: WVDELV, WVDELU, TAUTMP, QQWVTMP
  
  LOGICAL, SAVE, ALLOCATABLE :: LOCALWAVEMASK(:)
  REAL, SAVE :: CDLIMIT
  REAL, SAVE, ALLOCATABLE :: ZBRATU(:)
  REAL, SAVE, ALLOCATABLE :: ZBRATV(:)
  REAL, SAVE, ALLOCATABLE :: SGZUU(:,:)
  REAL, SAVE, ALLOCATABLE :: SGZVV(:,:)

  DELT = DT2  
  IF( ISTL /= 3 )THEN  
    DELT = DT  
  ENDIF  
  IF( IS2TL == 1 )THEN  
    IF( ISDYNSTP == 0 )THEN  
      DELT = DT  
    ELSE  
      DELT = DTDYN  
    END IF  
  ENDIF  
  DELTI = 1./DELT  
  
  ! **  INITIALIZE IMPLICIT BOTTOM FRICTION AND SET DIAGNOSTIC FILES ON FIRST CALL  
  IF( JSTBXY == 0 )THEN
    ! *** FIRST CALL
    ALLOCATE(LOCALWAVEMASK(LCM))
    DO L = 2,LA
      LOCALWAVEMASK(L) = .NOT. LWVMASK(L)
    ENDDO
    
    ! *** ZBRATU & ZBRATV - AVERAGE WEIGHTED ROUGHNESS HEIGHTS
    ALLOCATE(ZBRATU(LCM))
    ALLOCATE(ZBRATV(LCM))
    ALLOCATE(SGZUU(LCM,KCM))
    ALLOCATE(SGZVV(LCM,KCM))
    
    DO L = 2,LA  
      LW = LWC(L)
      LS = LSC(L)
      ZBRATU(L) = 0.5*(DXP(LW)*ZBR(LW) + DXP(L)*ZBR(L))*DXIU(L)
      ZBRATV(L) = 0.5*(DYP(LS)*ZBR(LS) + DYP(L)*ZBR(L))*DYIV(L)  
      DO K = 1,KC
        SGZUU(L,K) = 0.5*MAX(DZC(L,K),SGZU(L,K))
        SGZVV(L,K) = 0.5*MAX(DZC(L,K),SGZV(L,K))
      ENDDO
    ENDDO

    ! *** Set drag coefficient limits and weighting fractions
    IF( ISITB >= 1 )THEN  
      ! *** ISVEG > 0 case and implicit drag is used
      IF( ISITB == 1 )THEN  
        RITB1 = 0.45      ! *** WEIGHTED EXPLICIT FRACTION
        RITB = 0.55       ! *** WEIGHTED IMPLICIT FRACTION
        CDLIMIT = 10.  
      ELSE  
        RITB1 = 0.0       ! *** ZERO EXPLICIT FRACTION  
        RITB = 1.0        ! *** FULL IMPLICIT FRACTION
        CDLIMIT = 100.  
      ENDIF  
    ELSE  
      RITB1 = 1.0         ! *** FILL EXPLICIT FRACTION  
      RITB = 0.0          ! *** ZERO IMPLICIT FRACTION 
      CDLIMIT = 0.5  
    ENDIF  
    
    DO L = 2,LA  
      STBXO(L) = STBX(L)  
      STBYO(L) = STBY(L)  
    ENDDO  
    DO L = 1,LC  
      STBX(L) = 0.        ! *** STBX - DRAG COEFFICIENT IN THE U DIRECTION
      STBY(L) = 0.        ! *** STBY - DRAG COEFFICIENT IN THE V DIRECTION
      ZBRE(L) = KSW/30.   ! *** ZBRE - BED ROUGHNESS USED FOR WAVE CALCULATIONS
    ENDDO
    
    IF( ISVEG > 0 )THEN
      DO K = 1,KC  
        DO L = 1,LC  
          FXVEG(L,K) = 0.  
          FYVEG(L,K) = 0.  
        ENDDO  
      ENDDO  

      ! *** GET THE VEGETATION CELL FLAG
      LVEG = .FALSE.
      DO L = 2,LA
        M = MVEGL(L)  
        IF( M /= MVEGOW .AND. M /= 0 )THEN
          LVEG(L) = .TRUE.                                ! *** Not open water or uninitialized devices
        ENDIF
      ENDDO
      
      ! *** GET THE VEGETATION CELL FLAG FOR MACROPHYTES
      IF( ISTRAN(8) > 0 )THEN
        DO L = 2,LA
          DO NAL = 1,NALGAE
            IF( ALGAES(NAL).ISMOBILE .AND. ALGAES(NAL).ISDRAG > 0 )THEN
              IF( SUM(WQV(L,:,19 + NAL)) >= 0.001 )THEN
                LVEG(L) = .TRUE.                          ! *** This is a macrophyte cell that includes drag
              ENDIF
            ENDIF
          ENDDO
        ENDDO
      ENDIF
      
      ! *** GET THE VEGETATION CELL COUNT AND LIST BY LAYER
      ALLOCATE(LLVEG(KCM,NDM))
      ALLOCATE(LKVEG(LCM,KCM,NDM))
      LLVEG = 0
      LKVEG = 0
      DO ND = 1,NDM  
        DO K = 1,KC  
          LN = 0
          DO LP = 1,LLWET(K,ND)
            L = LKWET(LP,K,ND)  
            IF( LVEG(L) )THEN
              LN = LN + 1
              LKVEG(LN,K,ND) = L
            ENDIF
          ENDDO
          LLVEG(K,ND) = LN    ! *** NUMBER OF WET VEG CELLS FOR THE CURRENT LAYER
        ENDDO
      ENDDO

      ! *** DEACTIVATE VEGETATION FOR OPEN BC CELLS
      IF( NBCSOP > 0 )THEN
        DO IOBC = 1,NBCSOP  
          L = LOBCS(IOBC)  
          MVEGL(L) = 0.
        ENDDO  
        DO IOBC = 1,NBCSOP2 
          L = LOBCS2(IOBC)  
          MVEGL(L) = 0.
        ENDDO
      ENDIF
    ENDIF  ! *** END OF ISVEG > 0 
    N = -2  
    JSTBXY = 1  

    ! *** CHECK FOR SMOOTH DRAG FORMULATION
    DO L = 2,LA
      IF( ZBR(L) <= 1.E-6 )THEN
        ICALTB = 1   ! *** SET BOTTOM DRAG APPROACH TO EFDCPLUS APPROACH
        EXIT
      ENDIF
    ENDDO
    
#   ifdef _MPI
    ! ****************************************************************************
    ! *** MPI communication
    Call MPI_barrier(MPI_Comm_World, ierr)
    Call communicate_ghost_cells(ZBRATU, 'ZBRATU')
    Call communicate_ghost_cells(ZBRATV, 'ZBRATV')
    Call communicate_ghost_cells(SGZUU)
    Call communicate_ghost_cells(SGZVV)
    ! ****************************************************************************
#   endif

  ENDIF   ! *** End of first call initializations

  IF( ISWAVE > 0 )THEN
    ! *** COMPUTE RAMPUP FACTOR
    NTMP = MAX(N,1)  
    IF( NTMP < NTSWV )THEN  
      TMPVALW = FLOAT(NTMP)/FLOAT(NTSWV)  
      WVFACT = 0.5-0.5*COS(PI*TMPVALW)  
    ELSE  
      WVFACT = 1.0  
    ENDIF  
    RKZTURB = 0.4/CTURB3
    LDMW = INT(FLOAT(NWVCELLS)/FLOAT(NDM)) + 1
  ENDIF
  
  ! **  INITIALIZED DIAGNOSTICS FOR STANDARD AND VEGE RESISTANCE CALCULATION  
  CDTOTUM = 0.  
  CDTOTVM = 0.  
  CDMAXUM = 0.  
  CDMAXVM = 0.  
  IF( ISVEG == 0 ) UVEGSCL = 1.E-12

  ! *********************************************************************************
  ! *** NORMAL ENTRY INTO STANDARD AND VEGE RESISTANCE CALCULATION 
  ! ***  FOR SINGLE AND MULTIPLE LAYERS
  VISEXP = 2./7.
  VISFAC = 0.0258*(COEFTSBL**VISEXP)
  
  ! *** ZERO NEWLY DRY CELLS
  IF( LADRY > 0 )THEN
    DO LP = 1,LADRY
      L = LDRY(LP)  
      VEGK(L) = 0.
      QQ(L,0) = 0.
      QQSQR(L,0) = 0.
      TBX(L) = 0.
      TBY(L) = 0.
      TBX(LEC(L)) = 0.
      TBY(LNC(L)) = 0.
      TSX(L) = 0.
      TSY(L) = 0.
      TSX(LEC(L)) = 0.
      TSY(LNC(L)) = 0.
    ENDDO
 
    IF( ISVEG > 0 )THEN
      DO K = 1,KC
        DO LP = 1,LADRY
          L = LDRY(LP)  
          FXVEG(L,K) = 0.
          FYVEG(L,K) = 0.
        ENDDO
      ENDDO
    ENDIF
  ENDIF
  
  !$OMP PARALLEL DEFAULT(SHARED) 

  ! *********************************************************************************
  ! *** WAVE-CURRENT BOUNDARY LAYER  
  IF( (ISWAVE == 2 .OR. ISWAVE == 4) .AND. .NOT. LSEDZLJ )THEN
    !$OMP DO PRIVATE(ND,L,LF,LL,LWAVE)  &
    !$OMP    PRIVATE(QQWCTMP,TWCTMP,AEXTMP,TAUTMP,TMPVAL,USTARC,CDRGTMP) &
    !$OMP    PRIVATE(TAUBTMP,TAUE,RIPAMP,RIPSTP,RIPFAC,QQWVTMP)
    DO ND = 1,NDM  
      LF = 1 + (ND-1)*LDMW  
      LL = MIN(LF + LDMW-1,NWVCELLS)

      ! *** Update water column turbulent intensity by wave action
      DO LWAVE = LF,LL  
        L = LWVCELL(LWAVE)

        ! *** SET ZBRE AS GRAIN/SKIN ROUGHNESS (M)  (NIKURADSE ROUGHNESS)
        ZBRE(L) = KSW/30.

        IF( UWVSQ(L) > 1.E-6 .AND. LMASKDRY(L) .AND. HP(L) > HDRYWAV )THEN  
          
          ! *** QQ(L,0) - (m2/s2) N-1 Total Bed Shear Turbulent Intensity
          ! *** QQWV2   - (m2/s2) N-1 Water Column Turbulent Intensity due to waves only
          QQWCTMP = SQRT( QQWV2(L)*QQWV2(L) + QQ(L,0)*QQ(L,0) )          

          TWCTMP = QQWCTMP/CTURB2
          AEXTMP = 0.5*WV(L).HEIGHT/SINH(WV(L).KHP)                 
          IF( ISTRAN(7) > 0 )THEN  
            TAUTMP = TWCTMP/TAUCMIN
            TMPVAL = 1. + 1.2*TAUTMP/(1. + 0.2*TAUTMP)
            ZBRE(L) = ZBRE(L)*TMPVAL
          ELSEIF( QQ(L,0) > 0. )THEN
            USTARC = SQRT(QQ(L,0)/CTURB2)  
            TMPVAL = TWCTMP/USTARC  
            ZBRE(L) = ZBRE(L)*(1. + 0.19*TMPVAL)  
          ENDIF
          CDRGTMP = (30.*ZBRE(L)/AEXTMP)**0.2  
          CDRGTMP = 5.57*CDRGTMP-6.13  
          CDRGTMP = EXP(CDRGTMP)  
          CDRGTMP = MIN(CDRGTMP,0.22)  
          TAUTMP = 0.5*CDRGTMP*UWVSQ(L)   

          ! *** Recalculate Turbulent Intensity due to waves
          
          QQWVTMP = CTURB2*TAUTMP*WVFACT
          
          ! *** COMPUTE MOVING BED EFFECTS
          IF( ISTRAN(7) > 0 .AND. ISWCBL == 2 )THEN
            QQWC(L) = SQRT( QQWVTMP*QQWVTMP + QQ(L,0)*QQ(L,0) )   ! *** Combined wave/current for stationary bed (m2/s2)
            TWCTMP = QQWC(L)/CTURB2
            TAUBTMP = QQWVTMP/CTURB2
            TAUE = TWCTMP/TAUN(NSED + 1)
            RIPAMP = 0.
            RIPSTP = 0.
            IF( TAUBTMP>TAUN(NSED + 1) .AND. TAUBTMP <= TAUD(NSED + 1) )THEN
             RIPAMP = 0.22/(TAUE**0.16)
             RIPSTP = 0.16/(TAUE**0.04)
            ENDIF
            IF( TAUBTMP>TAUD(NSED + 1) )THEN
             RIPAMP = 0.78/(TAUE**1.5)
             RIPSTP = 0.41/TAUE
            ENDIF
            RIPAMP = RIPAMP*WV(L).HEIGHT/SINH(WV(L).KHP)
            TMPVAL = 0.
            IF( RIPAMP>0.) TMPVAL = LOG(RIPAMP/ZBRE(L))-1.
            TMPVAL = MAX(TMPVAL,0.)
            RIPFAC = 1. + 3.125*TMPVAL*TMPVAL*RIPSTP
            QQWV3(L) = RIPFAC*QQWVTMP
          ELSE
            QQWV3(L) = QQWVTMP  
          ENDIF

          ! *** Maximum magnitude without accounting for wave/current interactions (m2/s2)
          QQWCR(L) = SQRT( QQWV3(L)*QQWV3(L) + QQ(L,0)*QQ(L,0) )

        ELSE  
          QQWV3(L) = 1.E-12
          QQWCR(L) = 1.E-12
        ENDIF  
      ENDDO   ! *** END OF LWAVE LOOP
    ENDDO     ! *** END OF DOMAIN
    !$OMP END DO
  
    ! *** Bed shear stress by current & wave
    !$OMP DO PRIVATE(ND,L,LF,LL,LE,LS,LN,LW,LWAVE)  &
    !$OMP    PRIVATE(UTMP,VTMP,CURANG,COSWC,UMAGTMP,VMAGTMP,CDMAXU,CDMAXV,CDTMPU,CDTMPV,WVDTMP,WVDELU,WVDELV)  &
    !$OMP    PRIVATE(QWCTMPU,QWCTMPV,QCTMPU,QCTMPV,QWDQCU,QWDQCV,HZREFU,HZREFV,ZBREU,ZBREV,BOTTMP )  &
    !$OMP    PRIVATE(ZDHZRU,ZDHZRV,HZRUDZ,HZRVDZ,DWUD2Z,DWVD2Z,DWUDZ,DWVDZ,DWUDHR,DWVDHR,CDTMPUX,CDTMPVY)
    DO ND = 1,NDM  
      LF = 1 + (ND-1)*LDMW  
      LL = MIN(LF + LDMW-1,NWVCELLS)

      ! *** Update bed drag coefficients STBX and STBY based on wave and current angles
      DO LWAVE = LF,LL  
        L = LWVCELL(LWAVE)

        IF( UWVSQ(L) > 1.E-6 .AND. LMASKDRY(L) )THEN
          LE = LEC(L)
          LS = LSC(L)  
          LN = LNC(L)
          LW = LWC(L)
              
          ! *** Avg Velocities at U & V Faces
          UTMP = 0.5*STCUV(L)*(U(LE,KSZ(LE)) + U(L,KSZ(L))) + 1.E-12  
          VTMP = 0.5*STCUV(L)*(V(LN,KSZ(LN)) + V(L,KSZ(L)))  
          CURANG = ATAN2(VTMP,UTMP)
            
          ! *** Cosine of the Current - Wave  
          COSWC = COS(CURANG-WV(L).DIR)
            
          ! *** Velocites at Corners  
          UMAGTMP = SQRT( U1(L,KSZ(L))*U1(L,KSZ(L)) + V1U(L)      *V1U(L)      +1.E-12 )  
          VMAGTMP = SQRT( U1V(L)      *U1V(L)       + V1(L,KSZ(L))*V1(L,KSZ(L)) + 1.E-12 )
            
          ! *** Set Initial Drag Coefficients  
          CDMAXU = STBXO(L)*H1U(L)/( 4.*DELT*UMAGTMP )  
          CDMAXV = STBYO(L)*H1V(L)/( 4.*DELT*VMAGTMP )  
          CDTMPU = -1.  
          CDTMPV = -1.
            
          ! *** Avg Wave Turbulence at U & V Faces  
          QWCTMPU = 0.5*( QQWV3(L) + QQWV3(LE) )  
          QWCTMPV = 0.5*( QQWV3(L) + QQWV3(LS) )  
            
          IF( ISWCBL == 2 )THEN  
            QWCTMPU = 0.5*( QQWC(L) + QQWC(LE) )  
            QWCTMPV = 0.5*( QQWC(L) + QQWC(LS) )  
          ENDIF
             
          IF( WV(L).FREQ > 1E-6 )THEN
            WVDTMP = 0.4/(WV(L).FREQ*CTURB3)
          ELSE
            WVDTMP = 0.
          ENDIF  
          WVDELU = WVDTMP*SQRT(QWCTMPU)  
          WVDELV = WVDTMP*SQRT(QWCTMPV)
            
          ! *** Avg Wave & Current Stress  
          QWCTMPU = 0.5*( QQWCR(L) + QQWCR(LE) )  
          QWCTMPV = 0.5*( QQWCR(L) + QQWCR(LS) )
            
          ! *** Avg Shear Velocities  
          QWCTMPU = SQRT(QWCTMPU)  
          QWCTMPV = SQRT(QWCTMPV)
            
          ! *** Avg Total Bottom Shear  
          QCTMPU = 0.5*( QQ(L,0) + QQ(LE,0) )  
          QCTMPV = 0.5*( QQ(L,0) + QQ(LS,0) ) 
            
          IF( QCTMPU /= 0 )THEN
            QWDQCU = QWCTMPU/SQRT(QCTMPU)  
          ELSE
            QWDQCU = 0
          ENDIF
          IF( QCTMPV /= 0 )THEN
            QWDQCV = QWCTMPV/SQRT(QCTMPV)
          ELSE
            QWDQCV = 0
          ENDIF
            
          ! *** Thickness of Bottom Layer  
          HZREFU = DZC(L,KSZ(L))*H1U(L)  
          HZREFV = DZC(L,KSZ(L))*H1V(L)
            
          ! *** Avg Bottom roughness  
          ZBREU = 0.5*(ZBRE(L) + ZBRE(LE))  
          ZBREV = 0.5*(ZBRE(L) + ZBRE(LS))
            
          ! *** Ratio of Roughness to layer thickness  
          ZDHZRU = ZBREU/HZREFU  
          ZDHZRV = ZBREV/HZREFV  
          HZRUDZ = 1./ZDHZRU  
          HZRVDZ = 1./ZDHZRV  
          DWUD2Z = 0.5*WVDELU/ZBREU  
          DWVD2Z = 0.5*WVDELV/ZBREV  
          DWUDZ = 2.*DWUD2Z  
          DWVDZ = 2.*DWVD2Z  
          DWUDHR = WVDELU/HZREFU  
          DWVDHR = WVDELV/HZREFV  
          CDTMPUX = RKZTURB*QWCTMPU  
          CDTMPVY = RKZTURB*QWCTMPV  
          IF( HZRUDZ <= DWUD2Z )THEN  
            CDTMPU = CDTMPUX/( (1. + ZDHZRU)*LOG(1. + HZRUDZ)-1. )  
          ENDIF  
          IF( HZRVDZ <= DWVD2Z )THEN  
            CDTMPV = CDTMPVY/( (1. + ZDHZRV)*LOG(1. + HZRVDZ)-1. )  
          ENDIF  
          IF( HZRUDZ > DWUD2Z .AND. HZRUDZ <= DWUDZ )THEN  
            BOTTMP = (1. + ZDHZRU)*LOG(1. + DWUD2Z)-0.5*DWUDHR + 0.5*HZRUDZ*(1.-0.5*DWUDHR)*(1.-0.5*DWUDHR)/(1. + DWUD2Z)  
            CDTMPU = CDTMPUX/BOTTMP  
          ENDIF  
          IF( HZRVDZ > DWVD2Z .AND. HZRVDZ <= DWVDZ )THEN  
            BOTTMP = (1. + ZDHZRV)*LOG(1. + DWVD2Z)-0.5*DWVDHR + 0.5*HZRVDZ*(1.-0.5*DWVDHR)*(1.-0.5*DWVDHR)/(1. + DWVD2Z)  
            CDTMPV = CDTMPVY/BOTTMP  
          ENDIF  
          IF( HZRUDZ > DWUDZ )THEN  
            BOTTMP = QWDQCU*( (1. + ZDHZRU)*(LOG(1. + HZRUDZ)-LOG(1. + DWUDZ)) + DWUDHR-1. )  
            BOTTMP = BOTTMP + (1. + ZDHZRU)*LOG(1. + DWUD2Z) + DWUD2Z*(1.-1.25*DWUDHR-ZDHZRU)/(1. + DWUD2Z)
            CDTMPU = CDTMPUX/BOTTMP  
          ENDIF  
          IF( HZRVDZ > DWVDZ )THEN  
            BOTTMP = QWDQCV*( (1. + ZDHZRV)*(LOG(1. + HZRVDZ)-LOG(1. + DWVDZ)) + DWVDHR-1. )  
            BOTTMP = BOTTMP + (1. + ZDHZRV)*LOG(1. + DWVD2Z) + DWVD2Z*(1.-1.25*DWVDHR-ZDHZRV)/(1. + DWVD2Z)  
            CDTMPV = CDTMPVY/BOTTMP  
          ENDIF  
          CDTMPU = CDTMPU/UMAGTMP  
          CDTMPV = CDTMPV/VMAGTMP
            
          IF( CDTMPU <= 0.) CDTMPU = CDMAXU  
          IF( CDTMPV <= 0.) CDTMPV = CDMAXV  
            
          STBX(L) = STBXO(L)*CDTMPU
          STBY(L) = STBYO(L)*CDTMPV  
          STBX(L) = MIN(CDMAXU,STBX(L))
          STBY(L) = MIN(CDMAXV,STBY(L))
 
        ENDIF
      ENDDO  ! *** END OF LWAVE LOOP
    ENDDO    ! *** END OF DOMAIN
    !$OMP END DO
  
  ELSEIF( (ISWAVE == 1 .OR. ISWAVE == 3) .AND. .NOT. LSEDZLJ )THEN
    !$OMP SINGLE
    QQWV3 = QQWV1
    !$OMP END SINGLE
  ENDIF      ! *** END OF BLOCK FOR WAVE-BOUNDARY LAYER APPROACH

  ! ******************************************************************************
  ! *** BED STRESS FOR NON-WAVE CELLS
  
  !$OMP DO PRIVATE(ND,LF,LL,LP,L)  &
  !$OMP    PRIVATE(UMAGTMP,VMAGTMP,CDMAXU,CDMAXV,VISMUDU,VISMUDV,SEDTMP,VISDHU,VISDHV)  &
  !$OMP    PRIVATE(HURTMP,HVRTMP,HUDZBR,HVDZBR,DZHUDZBR,DZHVDZBR)  
  DO ND = 1,NDM  
    LF = (ND-1)*LDMWET + 1  
    LL = MIN(LF + LDMWET-1,LAWET)

    IF( ICALTB == 0 )THEN
      ! *** DSI DEFAULT.  CONSISTENT WITH THEORY AND HANDLES THIN BOTTOM LAYERS
      DO LP = LF,LL
        L = LWET(LP)  
        IF( LOCALWAVEMASK(L) .OR. QQWV2(L) <= 1.E-12 )  THEN 
          ! *** SET DRAG COEFFICIENT LIMITS
          UMAGTMP = SQRT( VU(L)*VU(L) + U(L,KSZU(L))*U(L,KSZU(L)) + 1.E-12 )  
          VMAGTMP = SQRT( UV(L)*UV(L) + V(L,KSZV(L))*V(L,KSZV(L)) + 1.E-12 )  
          CDMAXU = CDLIMIT*HU(L)/( DELT*UMAGTMP )  
          CDMAXV = CDLIMIT*HV(L)/( DELT*VMAGTMP )  

          ! *** HU & HV - FLOW DEPTHS AT CELL INTERFACE
          HUDZBR = HU(L)/ZBRATU(L)
          HVDZBR = HV(L)/ZBRATV(L)  
          HUDZBR = MAX(HUDZBR,7.5)
          HVDZBR = MAX(HVDZBR,7.5)
            
          ! *** NEZU & NAKAGAWA (1993) WHERE THE WAKE PARAMETER IS 0.2  FOR TURBULENT CONDITIONS.  -0.8 = WAKE - 1.
          STBX(L) = (VKC/(LOG( HUDZBR ) - 0.8))**2 
          STBY(L) = (VKC/(LOG( HVDZBR ) - 0.8))**2  
              
          STBX(L) = MIN(CDMAXU, STBX(L) )
          STBY(L) = MIN(CDMAXV, STBY(L) )
        ENDIF
      ENDDO
      
    ELSE
      ! *** LEGACY APPROACHES
      DO LP = LF,LL
        L = LWET(LP)  
        IF( LOCALWAVEMASK(L) .OR. QQWV2(L) <= 1.E-12 )  THEN 
          IF( ZBR(L) <= 1.E-6 )THEN  
            ! **  BEGIN SMOOTH DRAG FORMULATION  
            UMAGTMP = SQRT( U(L,KSZ(L))*U(L,KSZ(L)) + VU(L)      *VU(L)       + 1.E-12 )  
            VMAGTMP = SQRT( UV(L)      *UV(L)       + V(L,KSZ(L))*V(L,KSZ(L)) + 1.E-12 )  
            CDMAXU = CDLIMIT*STBXO(L)*HU(L)/( DELT*UMAGTMP )  
            CDMAXV = CDLIMIT*STBYO(L)*HV(L)/( DELT*VMAGTMP )
            
            VISMUDU = VISMUD
            VISMUDV = VISMUD
            IF( ISMUD >= 1 )THEN  
              SEDTMP = 0.5*(SED(L,KSZ(L),1) + SED(LWC(L),KSZ(LWC(L)),1))  
              VISMUDU = CSEDVIS(SEDTMP)  
              SEDTMP = 0.5*(SED(L,KSZ(L),1) + SED(LSC(L),KSZ(LSC(L)),1))  
              VISMUDV = CSEDVIS(SEDTMP)  
            ENDIF  
            VISDHU = 0.0
            VISDHV = 0.0
            IF( UMAGTMP > 0.0) VISDHU = (VISMUDU*HUI(L)/UMAGTMP)*VISEXP
            IF( VMAGTMP > 0.0) VISDHV = (VISMUDV*HVI(L)/VMAGTMP)*VISEXP
            STBX(L) = VISFAC*STBXO(L)*VISDHU
            STBY(L) = VISFAC*STBYO(L)*VISDHV
            STBX(L) = MIN(CDMAXU,STBX(L))  
            STBY(L) = MIN(CDMAXV,STBY(L))  
        
          ELSE IF( ISAVCOMP > 0 )THEN  
            ! **  BEGIN ROUGH DRAG FORMULATION  
            IF( ICALTB == 1 )THEN
              ! *** PRE DSI VERSION 10.0 APPROACH
              UMAGTMP = SQRT( VU(L)*VU(L) + U(L,KSZU(L))*U(L,KSZU(L)) + 1.E-12 )  
              VMAGTMP = SQRT( UV(L)*UV(L) + V(L,KSZV(L))*V(L,KSZV(L)) + 1.E-12 )  
              CDMAXU = CDLIMIT*STBXO(L)*HU(L)/( DELT*UMAGTMP )  
              CDMAXV = CDLIMIT*STBYO(L)*HV(L)/( DELT*VMAGTMP )  

              ! *** HURTMP & HVRTMP - FLOW DEPTHS AT FACE
              HURTMP = MAX(ZBRATU(L), H1U(L))
              HVRTMP = MAX(ZBRATV(L), H1V(L))

              ! *** HANDLE LAYER ISSUES              
              IF( KSZ(L) == KC )THEN    ! *** Alberta
                HUDZBR = 0.5*HURTMP/ZBRATU(L)  
                HUDZBR = MAX(HUDZBR,7.5)
                HVDZBR = 0.5*HVRTMP/ZBRATV(L)  
                HVDZBR = MAX(HVDZBR,7.5)
                STBX(L) = STBXO(L)*0.16/( (LOG( HUDZBR ) -1.)**2)  
                STBY(L) = STBYO(L)*0.16/( (LOG( HVDZBR ) -1.)**2)  
              ELSE                
                DZHUDZBR = 1. + SGZUU(L,KSZU(L))*HURTMP/ZBRATU(L)
                DZHVDZBR = 1. + SGZVV(L,KSZV(L))*HVRTMP/ZBRATV(L)
                DZHUDZBR = MAX(DZHUDZBR,7.5)  ! *** APPLY THE SAME LIMIT AS KC = 1
                DZHVDZBR = MAX(DZHVDZBR,7.5)  ! *** APPLY THE SAME LIMIT AS KC = 1
                STBX(L) = STBXO(L)*0.16/((LOG(DZHUDZBR))**2)  
                STBY(L) = STBYO(L)*0.16/((LOG(DZHVDZBR))**2) 
              ENDIF
              STBX(L) = MIN(CDMAXU, STBX(L) )
              STBY(L) = MIN(CDMAXV, STBY(L) )

            ELSEIF( ICALTB == 2 )THEN
              ! *** LEGACY VERSION
              UMAGTMP = SQRT( V1U(L)*V1U(L) + U1(L,KSZU(L))*U1(L,KSZU(L)) + 1.E-12 )  
              VMAGTMP = SQRT( U1V(L)*U1V(L) + V1(L,KSZV(L))*V1(L,KSZV(L)) + 1.E-12 )  
              CDMAXU = CDLIMIT*STBXO(L)*H1U(L)/( DELT*UMAGTMP )  
              CDMAXV = CDLIMIT*STBYO(L)*H1V(L)/( DELT*VMAGTMP )  

              ! *** HURTMP & HVRTMP - FLOW DEPTHS AT FACE
              HURTMP = MAX(ZBRATU(L), H1U(L))
              HVRTMP = MAX(ZBRATV(L), H1V(L))

              DZHUDZBR = 1. + SGZUU(L,KSZU(L))*HURTMP/ZBRATU(L)
              DZHVDZBR = 1. + SGZVV(L,KSZV(L))*HVRTMP/ZBRATV(L)
            
              STBX(L) = STBXO(L)*.16/((LOG(DZHUDZBR))**2)  
              STBY(L) = STBYO(L)*.16/((LOG(DZHVDZBR))**2) 
              STBX(L) = MIN(CDMAXU, STBX(L) )
              STBY(L) = MIN(CDMAXV, STBY(L) )
            ENDIF
          ENDIF  
        ENDIF  
      ENDDO  
    ENDIF
  ENDDO   ! *** END OF DOMAIN
  !$OMP END DO

  ! *********************************************************************************
  ! *** BEGIN INTERNAL MODE VEGETATION DRAG
  IF( ISVEG >= 1 )THEN  
    !$OMP DO PRIVATE(ND,LF,LL,LP,L,K,LS,LW,LE,LN,LNW,LSE,MW,M,MS)  &
    !$OMP    PRIVATE(VTMPATU,UTMPATV,UMAGTMP,VMAGTMP,CPVEGU,CPVEGV )  &
    !$OMP    PRIVATE(HVGTC,HVGTW,HVGTS,FRACLAY,FHLAYC,FHLAYW,FHLAYS,CDMAXU,CDMAXV)  
    DO ND = 1,NDM  

      DO LP=1,LLVEG(KC,ND)
        ! *** ZERO ACTIVE VEGETATION LAYERS FOR WET CELLS
        L=LKVEG(LP,KC,ND) 
        VEGK(L) = 0.
      ENDDO

      DO K = 1,KC  
        DO LP = 1,LLVEG(K,ND)
          L = LKVEG(LP,K,ND)
          
          FXVEG(L,K) = 0.  
          FYVEG(L,K) = 0.  

          LW = LWC(L)
          LE = LEC(L)
          LS = LSC(L)  
          LN = LNC(L)  
          LNW = LNWC(L)  
          LSE = LSEC(L)  
          
          VTMPATU = 0.25*(V(L,K) + V(LW,K) + V(LN,K) + V(LNW,K))         ! *** Average U velocity at the V face
          UTMPATV = 0.25*(U(L,K) + U(LE,K) + U(LS,K) + U(LSE,K))         ! *** Average V velocity at the U face  
          UMAGTMP = SQRT( U(L,K)*U(L,K)   + VTMPATU*VTMPATU + 1.E-12 )   ! *** Magnitude of velocity at U face
          VMAGTMP = SQRT( UTMPATV*UTMPATV + V(L,K)*V(L,K)   + 1.E-12 )   ! *** Magnitude of velocity at V face
                  
          UMAGTMP = MAX(UMAGTMP,UVEGSCL)  
          VMAGTMP = MAX(VMAGTMP,UVEGSCL)  
          CDMAXU  = CDLIMIT*STBXO(L)*H1U(L)/( DELT*UMAGTMP )
          CDMAXV  = CDLIMIT*STBYO(L)*H1V(L)/( DELT*VMAGTMP ) 
          
          ! *** Handle macrophyte feedback in WQ model
          IF( MAC_CELL(L) )THEN
    
          ELSE
            ! *** Standard rigid 
            M = MVEGL(L)  
            IF( M > 90 ) M = M-90  !SCJ vegetation below MHK device, which is OK
          
            MW = MVEGL(LW)  
            IF( MW > 90 ) MW = MW-90  !SCJ, vegetation below MHK device, which is OK
            MS = MVEGL(LS)  
            IF( MS > 90 ) MS = MS-90  !SCJ, vegetation below MHK device, which is OK
              
            ! *** DRAG COEFFICIENT: U COMPONENT 
            CPVEGU = 1.0
            IF( ISVEGL == 1 ) CPVEGU = CPVEGU + 10.E-6/((BPVEG(MW) + BPVEG(M))*UMAGTMP )  
            IF( CPVEGU > 1.0 )THEN  
              ! *** CALCULATE R FOR LAMINAR FLOW  
              CPVEGU = CPVEGU-0.5  
            ENDIF
            CPVEGU = SCVEG(M)*CPVEGU  

            ! *** DRAG COEFFICIENT: V COMPONENT 
            CPVEGV = 1.0
            IF( ISVEGL == 1 ) CPVEGV = CPVEGV + 10.E-6/((BPVEG(MS) + BPVEG(M))*VMAGTMP )  
            IF( CPVEGV > 1.0 )THEN  
              ! *** CALCULATE R FOR LAMINAR FLOW  
              CPVEGV = CPVEGV-0.5  
            ENDIF  
            CPVEGV = SCVEG(M)*CPVEGV
              
            ! *** HANDLE LAYER ISSUES
            IF( KSZ(L) == KC )THEN    ! *** Alberta
              HVGTC = MIN(HPVEG(M),HP(L))  
              HVGTW = MIN(HPVEG(MW),HP(LW))  
              HVGTS = MIN(HPVEG(MS),HP(LS))  
            ELSE   !IF( MVEGL(L)<91 )THEN
              FRACLAY = Z(L,K) 
              FHLAYC = FRACLAY*HP(L)  
              FHLAYW = FRACLAY*HP(LW)  
              FHLAYS = FRACLAY*HP(LS)  
              HVGTC = HPK(L,K)  
              HVGTW = HPK(LW,K)
              HVGTS = HPK(LS,K)  
              IF( HPVEG(M) < FHLAYC )THEN         
                ! *** GRADUALLY DECREASE VEGETATION EFFECTS  (PMC)
                HVGTC = HPVEG(M)-HP(L)*Z(L,K-1)
                HVGTC = MAX(HVGTC,0.)
              ENDIF
              IF( HPVEG(MW) < FHLAYW )THEN 
                ! *** GRADUALLY DECREASE VEGETATION EFFECTS  (PMC)
                HVGTW = HPVEG(MW)-HP(LW)*Z(L,K-1)
                HVGTW = MAX(HVGTW,0.)
              ENDIF
              IF( HPVEG(MS) < FHLAYS )THEN
                ! *** GRADUALLY DECREASE VEGETATION EFFECTS  (PMC)
                HVGTS = HPVEG(MS)-HP(LS)*Z(L,K-1)
                HVGTS = MAX(HVGTS,0.)
              ENDIF
            ENDIF
            
            ! *** 0.25 factor is 0.5(drag force equation)*0.5(averaging face quantity)
            FXVEG(L,K) = 0.25*CPVEGU*(DXP(L) *(BDLPSQ(M) *HVGTC/PVEGZ(M)) +   &          ! *** dimensionless
                                      DXP(LW)*(BDLPSQ(MW)*HVGTW/PVEGZ(MW)))*DXIU(L)  
            FYVEG(L,K) = 0.25*CPVEGV*(DYP(L) *(BDLPSQ(M) *HVGTC/PVEGZ(M)) +   &          ! *** dimensionless
                                      DYP(LS)*(BDLPSQ(MS)*HVGTS/PVEGZ(MS)))*DYIV(L)  
            FXVEG(L,K) = MIN(FXVEG(L,K),CDMAXU)  
            FYVEG(L,K) = MIN(FYVEG(L,K),CDMAXV)

            ! *** ACCUMULATE ACTIVE VEGETATION LAYERS
            VEGK(L) = VEGK(L) + HVGTC*HPKI(L,K)
          ENDIF
        ENDDO   ! *** END OF LWET LOOP
      ENDDO     ! *** END OF KC LOOP  
    ENDDO       ! *** END OF DOMAIN
    !$OMP END DO
    
  ENDIF    ! *** END OF ISVEG>0
  ! *** END OF VEGETATION DRAG
  !$OMP END PARALLEL
  
  ! *********************************************************************************
  ! ** SUBGRID SCALE CHANNEL FRICTION  
  IF( MDCHH >= 1 )THEN  
    DO NMD = 1,MDCHH  
      LHOST = LMDCHH(NMD)  
      LCHNU = LMDCHU(NMD)  
      LCHNV = LMDCHV(NMD)  
      MH = MVEGL(LHOST)  

      ! *** X-DIRECTION CHANNEL  
      IF( MDCHTYP(NMD) == 1 )THEN  
        MU = 0  
        IF( ISVEG >= 1 ) MU = MVEGL(LCHNU)  
        WCHAN = DXP(LCHNU)  
        RLCHN = 0.5*DYP(LCHNU) + CHANLEN(NMD)  
        HCHAN = 0.5*DYP(LCHNU)*H1P(LCHNU) + CHANLEN(NMD)*H1P(LHOST)  
        HCHAN = HCHAN/RLCHN  
        ZBRATUC = 0.5*DYP(LCHNU)*ZBR(LCHNU) + CHANLEN(NMD)*ZBR(LHOST)  
        ZBRATUC = ZBRATUC/RLCHN  
        HURTMP = MAX(ZBRATUC,HCHAN)  
        HUDZBR = HURTMP/ZBRATUC  
        IF( HUDZBR < 7.5) HUDZBR = 7.5  
        STBXCH = 0.16/( (LOG( HUDZBR ) -1.)**2)  
        CDMAXU = HCHAN*HCHAN*WCHAN/( DELT*(QCHANU(NMD) + 1.E-12) )  
        STBXCH = MAX(STBXCH,CDMAXU)  
        STBXCH = MAX(STBXCH,0.1)  
        FXVEGCH = 0.0  
        IF( MU > 0 ) FXVEGCH = 0.5*( 0.5*DYP(LCHNU)*(BDLPSQ(MU)*H1P(LCHNU)/PVEGZ(MU))  &
                                   + CHANLEN(NMD)*(BDLPSQ(MH)*H1P(LHOST)/PVEGZ(MH)) )/RLCHN  
        CHANFRIC(NMD) = FXVEGCH + STBXCH  
      ENDIF  

      ! *** Y-DIRECTION CHANNEL  
      IF( MDCHTYP(NMD) == 2 )THEN  
        MV = 0  
        IF( ISVEG >= 1 ) MV = MVEGL(LCHNV)  
        WCHAN = DYP(LCHNV)  
        RLCHN = 0.5*DXP(LCHNV) + CHANLEN(NMD)  
        HCHAN = 0.5*DXP(LCHNV)*H1P(LCHNV) + CHANLEN(NMD)*H1P(LHOST)  
        HCHAN = HCHAN/RLCHN  
        ZBRATVC = 0.5*DXP(LCHNV)*ZBR(LCHNV) + CHANLEN(NMD)*ZBR(LHOST)  
        ZBRATVC = ZBRATVC/RLCHN  
        HVRTMP = MAX(ZBRATVC,HCHAN)  
        HVDZBR = HVRTMP/ZBRATVC  
        IF( HVDZBR < 7.5) HVDZBR = 7.5  
        STBYCH = 0.16/( (LOG( HVDZBR ) -1.)**2)  
        CDMAXV = HCHAN*HCHAN*WCHAN/( DELT*(QCHANV(NMD) + 1.E-12) )  
        STBYCH = MAX(STBYCH,CDMAXV)  
        STBYCH = MAX(STBYCH,0.1)  
        FYVEGCH = 0.0  
        IF( MV > 0 ) FYVEGCH = 0.5*(0.5*DXP(LCHNV)*(BDLPSQ(MV)*H1P(LCHNV)/PVEGZ(MV))  &
                                  + CHANLEN(NMD)*(BDLPSQ(MH)*H1P(LHOST)/PVEGZ(MH)) )/RLCHN  
        CHANFRIC(NMD) = FYVEGCH + STBYCH  
      ENDIF  
    ENDDO  
  ENDIF  
  
  ! *********************************************************************************
  RETURN  

END  

