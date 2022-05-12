! ----------------------------------------------------------------------
!   This file is a part of EFDC+
!   Website:  https://eemodelingsystem.com/
!   Repository: https://github.com/dsi-llc/EFDC_Plus.git
! ----------------------------------------------------------------------
! Copyright 2021-2022 DSI, LLC
! Distributed under the GNU GPLv2 License.
! ----------------------------------------------------------------------
SUBROUTINE CALHDMF

  ! *** CALDMF CALCULATES THE HORIZONTAL VISCOSITY AND
  ! *** DIFFUSIVE MOMENTUM FLUXES. THE VISCOSITY, AH IS CALCULATED USING
  ! *** SMAGORINSKY'S SUBGRID SCALE FORMULATION PLUS A CONSTANT AHO

  ! *** ONLY VALID FOR ISHDMF >= 1
  !
  !----------------------------------------------------------------------------------------C
  ! CHANGE RECORD
  ! DATE MODIFIED     BY               DESCRIPTION
  !----------------------------------------------------------------------------------------!
  !    2019-06       PAUL M. CRAIG     CHANGED APPROACH FOR WALL ROUGHNESS AND FMDUY/FMDVX
  !    2015-06       PAUL M. CRAIG     IMPLEMENTED SIGMA-Z (SGZ) IN EE7.3
  !    2011-05       Paul M. Craig     Corrected DSQR equation from /4 to /2
  !    2011-03       Paul M. Craig     Rewritten to F90 and added OMP
  !    2008-10       SANG YUK          CORRECTED THE DIFFUSIVE MOMENTUM FLUXES COMPUTATION
  !    2004-11       PAUL M. CRAIG     REWRITTEN AND RESTRUCTURED

  USE GLOBAL

  IMPLICIT NONE

  INTEGER :: L, LW, K, LL, NQSTMP, IU, JU, KU, NWR, ND, LN, LS, LP, LE, LG

  REAL      :: SLIPCO, TMPVAL, DSQR, WVFACT
  REAL      :: DTMPH, DTMPX, AHWVX, DX2DZBR, DY2DZBR, CSDRAG, SLIPFAC, FACES

  REAL,SAVE,ALLOCATABLE,DIMENSION(:,:) :: AHEE
  REAL,SAVE,ALLOCATABLE,DIMENSION(:,:) :: AHNN
  REAL,SAVE,ALLOCATABLE,DIMENSION(:,:) :: SXY
  REAL,SAVE,ALLOCATABLE,DIMENSION(:,:) :: DYU1
  REAL,SAVE,ALLOCATABLE,DIMENSION(:,:) :: DYV1
  REAL,SAVE,ALLOCATABLE,DIMENSION(:,:) :: DXU1
  REAL,SAVE,ALLOCATABLE,DIMENSION(:,:) :: DXV1

  IF(  .NOT. ALLOCATED(AHEE) )THEN
    ALLOCATE(AHEE(LCM,KCM))
    ALLOCATE(AHNN(LCM,KCM))
    ALLOCATE(SXY( LCM,KCM))
    ALLOCATE(DYU1(LCM,KCM))
    ALLOCATE(DYV1(LCM,KCM))
    ALLOCATE(DXU1(LCM,KCM))
    ALLOCATE(DXV1(LCM,KCM))

    AHEE=0.0
    AHNN=0.0
    SXY=0.0
    DYU1=0.
    DYV1=0.
    DXU1=0.
    DXV1=0.
  ENDIF
  
  ! *** SXX+SYY DEFINED AT CELL CENTERS AND STORED IN DXU1(L,K)
  SLIPCO = 1.
  IF( AHD > 0.0 )THEN
    SLIPCO = 0.5/SQRT(AHD)
  ENDIF

  ! ****************************************************************************
  ! *** RESET CELL WHEN INITIALLY DRY
  IF( LADRY > 0 )THEN
    DO K=1,KC
      DO LP=1,LADRY
        L=LDRY(LP)
        AH(L,K)  = AHOXY(L)
        AHC(L,K) = AHOXY(L)
        DXU1(L,K) = 0.0
        DXV1(L,K) = 0.0
        DYU1(L,K) = 0.0
        DYV1(L,K) = 0.0
        FMDUX(L,K) = 0.0
        FMDUY(L,K) = 0.0
        FMDVY(L,K) = 0.0
        FMDVX(L,K) = 0.0
      ENDDO
    ENDDO
  ENDIF

  !$OMP PARALLEL DEFAULT(SHARED)

  IF( ISDRY > 0 .AND. LADRY > 0 )THEN
    !$OMP DO PRIVATE(ND,K,LN,LP,L)
    DO ND=1,NDM
      DO K=1,KC
        LN=0
        DO LP=1,LLWET(K,ND)
          L=LKWET(LP,K,ND)
          IF( LHDMF(L,K) )THEN
            LN = LN+1
            LKHDMF(LN,K,ND) = L
          ENDIF
        ENDDO
        LLHDMF(K,ND)=LN    ! *** NUMBER OF WET HDMF CELLS FOR THE CURRENT LAYER
      ENDDO
    ENDDO
    !$OMP END DO
  ENDIF

  !$OMP DO PRIVATE(ND,K,LP,L,LE,LN,LS,LW,TMPVAL,DX2DZBR,DY2DZBR,CSDRAG,SLIPFAC,FACES)
  DO ND=1,NDM
    ! **  CALCULATE HORIZONTAL VELOCITY SHEARS
    DO K=1,KC
      DO LP=1,LLHDMF(K,ND)
        L = LKHDMF(LP,K,ND)
        LE=LEC(L)
        LN=LNC(L)
        ! *** DXU1 = dU/dX, UNITS: 1/S
        DXU1(L,K) = ( U(LE,K) - U(L,K) )/DXP(L)
        ! *** DYV1 = dV/dY, UNITS: 1/S
        DYV1(L,K) = ( V(LN,K) - V(L,K) )/DYP(L)
      ENDDO
    ENDDO
    IF( ISHDMF == 1 .OR. ISHDMF == 2 )THEN
      ! *** HMD WITHOUT WALL EFFECTS

      ! *** DYU1 = dU/dY
      DO K=1,KC
        DO LP=1,LLHDMF(K,ND)
          L = LKHDMF(LP,K,ND)
          LS=LSC(L)
          DYU1(L,K) = ( U(L,K) - U(LS,K) )/DYV(L)
        ENDDO
      ENDDO

      ! *** DXV1 = dV/dX
      DO K=1,KC
        DO LP=1,LLHDMF(K,ND)
          L = LKHDMF(LP,K,ND)
          LW=LWC(L)
          DXV1(L,K) = ( V(L,K) - V(LW,K) )/DXU(L)
        ENDDO
      ENDDO

    ELSE
      ! *** HMD WITH WALL EFFECTS

      ! *** DYU1 = dU/dY, DXV1 = dV/dX
      DO K=1,KC
        DO LP=1,LLHDMF(K,ND)
          L = LKHDMF(LP,K,ND)
          FACES = SUB3D(L,K) + SUB3D(LEC(L),K) + SVB3D(L,K) + SVB3D(LNC(L),K)
          IF( FACES > 3.0 )THEN
            ! *** OPEN WATER - AVERAGE SHEARS FROM BOTH SIDES OF THE CELL
            DYU1(L,K) = 0.5*( ( U(L,K) - U(LSC(L),K) )/DYV(L) + ( U(L,K) - U(LNC(L),K) )/DYV(LNC(L)) )      ! *** DYU1 = dU/dY
            DXV1(L,K) = 0.5*( ( V(L,K) - V(LWC(L),K) )/DXU(L) + ( V(L,K) - V(LEC(L),K) )/DXU(LEC(L)) )      ! *** DXV1 = dV/dX
          ELSE
            ! *** NORTH/SOUTH WALLS
            FACES = SUB3D(L,K) + SUB3D(LEC(L),K)
            IF( FACES > 0.5 )THEN
              IF( SVB3D(L,K) > 0.5 .XOR. SVB3D(LNC(L),K) > 0.5 )THEN
                ! *** NORTH OR SOUTH FACE IS A WALL
                DY2DZBR = 1. + 0.5*DYP(L)/ZBRWALL
                CSDRAG  = 0.16/((LOG(DY2DZBR))**2)
                SLIPFAC  = SLIPCO*CSDRAG
                DYU1(L,K) = SLIPFAC*U(L,K)/DYP(L)
              ENDIF
            ENDIF

            ! *** EAST/WEST WALLS
            FACES = SVB3D(L,K) + SVB3D(LNC(L),K)
            IF( FACES > 0.5 )THEN
              IF( SUB3D(L,K) > 0.5 .XOR. SUB3D(LEC(L),K) > 0.5 )THEN
                ! *** EAST OR WEST FACE IS A WALL
                DY2DZBR = 1. + 0.5*DYP(L)/ZBRWALL
                CSDRAG  = 0.16/((LOG(DY2DZBR))**2)
                SLIPFAC  = SLIPCO*CSDRAG
                DXV1(L,K) = SLIPFAC*V(L,K)/DXP(L)
              ENDIF
            ENDIF
          ENDIF
        ENDDO
      ENDDO
    ENDIF
  ENDDO  ! *** END OF DOMAIN
  !$OMP END DO

  ! *** WITHDRAWAL/RETURN
  IF( NQWR > 0 )THEN
    !$OMP SINGLE
    DO NWR=1,NQWR
      ! *** Handle +/- Flows for Withdrawal/Return Structures
      NQSTMP = WITH_RET(NWR).NQWRSERQ
      IF( QWRSERT(NQSTMP) >= 0. )THEN
        ! *** Original Withdrawal/Return
        IU = WITH_RET(NWR).IQWRU
        JU = WITH_RET(NWR).JQWRU
        KU = WITH_RET(NWR).KQWRU
      ELSE
        ! *** Reverse Flow Withdrawal/Return
        IU = WITH_RET(NWR).IQWRD
        JU = WITH_RET(NWR).JQWRD
        KU = WITH_RET(NWR).KQWRD
      ENDIF
      DXU1(LIJ(IU,JU),KU)=0.0
      DXV1(LIJ(IU,JU),KU)=0.0
      DYU1(LIJ(IU,JU),KU)=0.0
      DYV1(LIJ(IU,JU),KU)=0.0
    ENDDO
    !$OMP END SINGLE
  ENDIF

  ! *** SXY = dU/dY + dV/dX
  !$OMP DO PRIVATE(ND,K,LP,L)
  DO ND=1,NDM
    DO K=1,KC
      DO LP=1,LLHDMF(K,ND)
        L = LKHDMF(LP,K,ND)
        SXY(L,K) = DYU1(L,K) + DXV1(L,K)
      ENDDO
    ENDDO
  ENDDO
  !$OMP END DO

  !$OMP DO PRIVATE(ND,K,LP,L,LS,LW,LN)  &
  !$OMP    PRIVATE(TMPVAL,DSQR,WVFACT,AHWVX,DTMPH,DTMPX)
  DO ND=1,NDM
    IF( AHD > 0.0 )THEN
      ! *** CALCULATE SMAGORINSKY HORIZONTAL VISCOSITY
      DO K=1,KC
        DO LP=1,LLHDMF(K,ND)
          L = LKHDMF(LP,K,ND)
          TMPVAL = AHDXY(L)*DXP(L)*DYP(L)
          DSQR = DXU1(L,K)*DXU1(L,K) + DYV1(L,K)*DYV1(L,K) + 0.5*SXY(L,K)*SXY(L,K)
          AH(L,K) = AHOXY(L) + TMPVAL*SQRT(DSQR)
        ENDDO
      ENDDO
    ELSEIF( N < 10 .OR. ISWAVE == 2 .OR. ISWAVE == 4 )THEN
      ! *** ONLY NEED TO ASSIGN INITIALLY
      DO K=1,KC
        DO LP=1,LLHDMF(K,ND)
          L = LKHDMF(LP,K,ND)
          AH(L,K) = AHOXY(L)
        ENDDO
      ENDDO
    ENDIF

    ! **  CALCULATE HORIZONTAL SMAG DIFFUSION DUE TO WAVE BREAKING
    IF( ISWAVE == 2 .OR. ISWAVE == 4 )THEN
      IF( WVLSH > 0.0 .OR. WVLSX > 0.0 )THEN
        IF( ISWAVE == 2 .AND. N < NTSWV )THEN
          TMPVAL=FLOAT(N)/FLOAT(NTSWV)
          WVFACT=0.5-0.5*COS(PI*TMPVAL)
        ELSE
          WVFACT=1.0
        ENDIF

        IF( ISDRY > 0 )THEN
          DO K=1,KC
            DO LP=1,LLHDMF(K,ND)
              L = LKHDMF(LP,K,ND)
              IF( LWVMASK(L) )THEN
                IF( LMASKDRY(L) )THEN
                  IF( WV(L).DISSIPA(K) > 0 )THEN
                    DTMPH=WV(L).DISSIPA(K)**0.3333
                  ELSE
                    DTMPH=0
                  ENDIF
                  TMPVAL=2.*PI/WV(L).FREQ     ! *** WAVE PERIOD
                  AHWVX=WVLSX*TMPVAL*TMPVAL
                  DTMPX=WV(L).DISSIPA(K)/HP(L)
                  AH(L,K)=AH(L,K)+WVFACT*(WVLSH*DTMPH*HP(L)+AHWVX*DTMPX)
                ENDIF
              ENDIF
            ENDDO
          ENDDO
        ELSE
          DO K=1,KC
            DO LP=1,LLHDMF(K,ND)
              L = LKHDMF(LP,K,ND)
              IF( LWVMASK(L) )THEN
                IF( WV(L).DISSIPA(K) > 0 )THEN
                  DTMPH=WV(L).DISSIPA(K)**0.3333
                ELSE
                  DTMPH=0
                ENDIF
                TMPVAL=2.*PI/WV(L).FREQ
                AHWVX=WVLSX*TMPVAL*TMPVAL
                DTMPX=WV(L).DISSIPA(K)/HP(L)
                AH(L,K)=AH(L,K)+WVFACT*(WVLSH*DTMPH*HP(L)+AHWVX*DTMPX)
              ENDIF
            ENDDO
          ENDDO
        ENDIF
      ENDIF
    ENDIF
  ENDDO  ! *** END OF DOMAIN
  !$OMP END DO

  !$OMP DO PRIVATE(ND,K,LP,L,LE,LS,LW,LN)
  DO ND=1,NDM

    ! **  CALCULATE DIFFUSIVE MOMENTUM FLUXES
    IF( ISHDMF == 1 .OR. ISHDMF == 2 )THEN
      ! *** NO WALL EFFECTS
      DO K=1,KC
        DO LP=1,LLHDMF(K,ND)
          L = LKHDMF(LP,K,ND)
          LE=LEC(L)
          LN=LNC(L)
          LS=LSC(L)
          LW=LWC(L)
          FMDUX(L,K) = ( DYP(L) *HP(L) *AH(L,K) *DXU1(L,K) - DYP(LW)*HP(LW)*AH(LW,K)*DXU1(LW,K) )  !*SUB(L)*SUB(LW)
          FMDUY(L,K) = ( DXU(LN)*HU(LN)*AH(LN,K)*SXY(LN,K) - DXU(L) *HU(L) *AH(L,K) *SXY(L,K)   )*SVB(LW)*SVB(L)*SVB(LE)*SUB(LS)*SUB(L)*SUB(LN)
          FMDVY(L,K) = ( DXP(L) *HP(L) *AH(L,K) *DYV1(L,K) - DXP(LS)*HP(LS)*AH(LS,K)*DYV1(LS,K) )  !*SVB(L)*SVB(LN)
          FMDVX(L,K) = ( DYV(LE)*HV(LE)*AH(LE,K)*SXY(LE,K) - DYV(L) *HV(L) *AH(L,K) *SXY(L,K)   )*SVB(LW)*SVB(L)*SVB(LE)*SUB(LS)*SUB(L)*SUB(LN)
        ENDDO
      ENDDO
    ELSE
      ! *** WITH WALL EFFECTS
      DO K=1,KC
        DO LP=1,LLHDMF(K,ND)
          L = LKHDMF(LP,K,ND)
          LE=LEC(L)
          LN=LNC(L)
          LS=LSC(L)
          LW=LWC(L)
          FMDUX(L,K) = ( DYP(L) *HP(L) *AH(L,K) *DXU1(L,K) - DYP(LW)*HP(LW)*AH(LW,K)*DXU1(LW,K) )
          FMDUY(L,K) = (                                   - DXU(L) *HU(L) *AH(L,K) *SXY(L,K)   )     ! exe16

          FMDVY(L,K) = ( DXP(L) *HP(L) *AH(L,K) *DYV1(L,K) - DXP(LS)*HP(LS)*AH(LS,K)*DYV1(LS,K) )
          FMDVX(L,K) = (                                   - DYV(L) *HV(L) *AH(L,K) *SXY(L,K)   )     ! exe16
        ENDDO
      ENDDO
    ENDIF
  ENDDO  ! *** END OF DOMAIN
  !$OMP END DO

  !$OMP END PARALLEL
  
  IF( ISDRY > 0 .AND. NASPECT > 0 )THEN
    ! *** ZERO XY COMPONENT FOR CELLS WITH HIGH ASPECT RATIOS
    !$OMP PARALLEL DO DEFAULT(NONE) SHARED(NDM,KC,LLHDMF,LKHDMF,LASPECT,FMDUY,FMDVX,DXP,DYP) PRIVATE(ND,K,LP,L)
    DO ND=1,NDM
      DO K=1,KC
        DO LP=1,LLHDMF(K,ND)
          L = LKHDMF(LP,K,ND)
          IF( LASPECT(L) )THEN
            FMDUY(L,K) = 0.
            FMDVX(L,K) = 0.
          ENDIF
        ENDDO
      ENDDO
    ENDDO
    !$OMP END PARALLEL DO
  ENDIF

  ! *** ZERO BOUNDARY CELL MOMENTUM DIFFUSION
  DO LL=1,NBCSOP
    L=LOBCS(LL)
    DO K=1,KC
      FMDUX(L,K)=0.0
      FMDUY(L,K)=0.0
      FMDVY(L,K)=0.0
      FMDVX(L,K)=0.0
    ENDDO
  ENDDO

  RETURN

END
