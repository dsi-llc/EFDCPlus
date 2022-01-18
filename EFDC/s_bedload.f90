! ----------------------------------------------------------------------
!   This file is a part of EFDC+
!   Website:  https://eemodelingsystem.com/
!   Repository: https://github.com/dsi-llc/EFDC_Plus.git
! ----------------------------------------------------------------------
! Copyright 2021-2022 DSI, LLC
! Distributed under the GNU GPLv2 License.
! ----------------------------------------------------------------------
SUBROUTINE BEDLOADJ
  !  Bedload transport subroutine based on Van Rijn's transport
  !  Equations.
  !
  !  University of California, Santa Barbara
  !  Craig Jones and Wilbert Lick
  
  ! ORIGINAL:  May 24, 2006
  !  Craig Jones and Scott James
  ! REVISED: Added toxics linkage and bedload mass balance updates - 2017-01-04
  !  Paul M. Craig
  ! REVISED: SIGMA-ZED AND OMP - 2016-11-07
  !  Paul M. Craig
  ! REVISED: Added bybass by class - 2020-01-12
  !  Paul M. Craig
  ! REVISED: Eliminated use of NNONCO.  Always check D50 - 2020-09-23
  !  Paul M. Craig
  
  USE GLOBAL    
#ifdef _MPI
  USE MPI
  Use Communicate_Ghost_Routines
#endif

  IMPLICIT NONE 
  
  INTEGER :: L, NS, NT, LW, LS, LE, LN, ND, LF, LL, LP, IERR
  INTEGER :: ISKIP(NSCM)
  
  REAL(RKD) :: UTMP, VTMP 

  REAL(RKD) ,SAVE,ALLOCATABLE,DIMENSION(:) :: DXUCM
  REAL(RKD) ,SAVE,ALLOCATABLE,DIMENSION(:) :: DYVCM
  REAL(RKD) ,SAVE,ALLOCATABLE,DIMENSION(:) :: DXYIPCM

  REAL(RKD), EXTERNAL :: DSTIME
  REAL(RKD)           :: TTDS, TWAIT          ! *** MODEL TIMING TEMPORARY VARIABLES

  IF( .NOT. ALLOCATED(DXUCM) )THEN
    ALLOCATE(DXUCM(LCM))
    ALLOCATE(DYVCM(LCM))
    ALLOCATE(DXYIPCM(LCM))
    DXUCM(2:LA) = DBLE(DXYP(2:LA))/DBLE(DXP(2:LA))*100._8
    DYVCM(2:LA) = DBLE(DXYP(2:LA))/DBLE(DYP(2:LA))*100._8
    DXYIPCM(2:LA) = DBLE(DXYIP(2:LA))/10000._8
    
    PSUS = 1.0   ! *** Default to any eroded cohesive sediments into the water column.  Logic below for non-cohesives
  ENDIF
  ISKIP = 1
  
  !$OMP PARALLEL DEFAULT(SHARED)
  
  ! *********************************************************************
  ! *** Setup for Toxics Transport using previous timestep CBL and CBLTOX
  IF( ISTRAN(5) > 0 )THEN
    !$OMP DO PRIVATE(ND,LF,LL,NT,NS,LP,L)
    DO ND=1,NDM  
      LF=(ND-1)*LDMSED+1  
      LL=MIN(LF+LDMSED-1,LASED)

      DO NT=1,NTOX
        DO NS=1,NSCM
          IF( D50(NS) < BEDLOAD_CUTOFF ) CYCLE
          DO LP=LF,LL
            L=LSED(LP)
            IF( CBL(L,NS) > 1.E-6 )THEN
              ! *** MG/G             MG/M2      CM2/G    M2/CM2 
              CBLTXCON(L,NS,NT) = CBLTOX(L,NT)/CBL(L,NS)/10000.
            ELSE
              CBLTXCON(L,NS,NT) = 0.0
            ENDIF
          ENDDO
        ENDDO
      ENDDO
    ENDDO
    !$OMP END DO
  ENDIF
  
  ! *** ************************************************************
  ! *** Calculate Percentage of erosion into suspension PSUS
  ! *** and whether the cell has bedload or not BLFLAG
  !$OMP DO PRIVATE(ND,LF,LL,LP,L,NS)
  DO ND=1,NDM  
    LF=(ND-1)*LDMSED+1  
    LL=MIN(LF+LDMSED-1,LASED)
    DO NS=1,NSCM
      IF( D50(NS) < BEDLOAD_CUTOFF ) CYCLE
      DO LP=LF,LL
        L=LSED(LP)
        USW(L,NS) = SQRT(TAU(L))/DWS(NS)   ! *** DWS is settling speed.  USW is the shear velocity
      ENDDO
    ENDDO
  ENDDO
  !$OMP END DO
  
  ! *** Loop below determines if bedload exists or not.  There are three regimes of tranport in this loop.
  ! *** the first conditional in the where check for a large enough particle's diameter and small enough
  ! *** shear velocity.  If the particle is too small or the shear velocity is too large, then all the sediment 
  ! *** transport is in the suspended load, specified by suspended probability (PSUS = 1).  If the particle
  ! *** is large enough and the shear velocity is small enough then we have two situations. In the first case, 
  ! *** shear stress tau is smaller than the critical shear velocity or if shear velocity is negative or zero
  ! *** then there is neither bedload transport or suspended load transport.  Otherwise, both bedload and suspended
  ! *** load transport exists.  Also calculated is the probability of suspension for suspended load PSUS (eqn. 8).
  !$OMP DO PRIVATE(ND,LF,LL,NS,LP,L)
  DO ND=1,NDM  
    LF=(ND-1)*LDMSED+1  
    LL=MIN(LF+LDMSED-1,LASED)
    DO NS=1,NSCM
      IF( D50(NS) < BEDLOAD_CUTOFF ) CYCLE
      DO LP=LF,LL
        L=LSED(LP)
        ! ***                     
        IF( USW(L,NS) < 4.0 )THEN                                 ! *** "USW(L,NS) < 4.0" is an out of range check
          IF( TAU(L) <= TCRE(NS) .OR. USW(L,NS) <= 0.0 )THEN
            ! *** Shear is too small to erode anything for current class
            PSUS(L,NS) = 0.0
          ELSE      
            ISKIP(NS) = 0
            PSUS(L,NS) = MAX((LOG(USW(L,NS))-LOG(SQRT(TCRSUS(NS))/DWS(NS)))/(LOG(4.0)-LOG(SQRT(TCRSUS(NS))/DWS(NS))),0.0)
          ENDIF
        ELSE
          ! *** Shear is high enough to move all eroded material to suspension
          PSUS(L,NS) = 1.0
        ENDIF 
      ENDDO
    ENDDO  
  ENDDO
  !$OMP END DO

  ! *** Compute the bedload velocities (cm/s) in the U and V directions
  !$OMP DO PRIVATE(ND,LF,LL,NS,LP,L)
  DO ND=1,NDM  
    LF=(ND-1)*LDMSED+1  
    LL=MIN(LF+LDMSED-1,LASED)
    DO NS=1,NSCM
      IF( D50(NS) < BEDLOAD_CUTOFF ) CYCLE
      IF( ISKIP(NS) == 0 )THEN
        DO LP=LF,LL
          L = LSED(LP)
          TRANS(L,NS) = MAX((TAU(L)-TCRE(NS))/TCRE(NS),0.0)                     ! *** eqn. 21
          DZBL(L,NS)  = D50(NS)/10000.0*0.3*DISTAR(NS)**0.7*SQRT(TRANS(L,NS))   ! *** eqn. 20b
          DZBL(L,NS)  = MIN(DZBL(L,NS), HPCM(L))                                ! *** Don't allow bedload height to exceed water column depth
          BLVEL(L,NS) = 1.5*TRANS(L,NS)**0.6*SQRT(((SEDDENS(NCORENO(IL(L),JL(L)))/WATERDENS) -1.0)*980.0*D50(NS)/10000.0)    ! *** eqn. 20a  (cm/s)
        ENDDO
      ENDIF
    ENDDO
  ENDDO
  !$OMP END DO
      
  !$OMP DO PRIVATE(ND,LF,LL,NS,LP,L,LS,LW)
  DO ND=1,NDM  
    LF=(ND-1)*LDMSED+1  
    LL=MIN(LF+LDMSED-1,LASED)
    DO NS=1,NSCM
      IF( D50(NS) < BEDLOAD_CUTOFF ) CYCLE
      IF( ISKIP(NS) == 0 )THEN
        DO LP=LF,LL
          ! *** Interpolate BLVEL onto faces
          L = LSED(LP)
          LS = LSC(L)
          LW = LWC(L)
          UBL(L,NS) = 0.5*SUB(L)*(BLVEL(L,NS)*UCELLCTR(L) + BLVEL(LW,NS)*UCELLCTR(LW))
          VBL(L,NS) = 0.5*SVB(L)*(BLVEL(L,NS)*VCELLCTR(L) + BLVEL(LS,NS)*VCELLCTR(LS))
        ENDDO
      ENDIF
    ENDDO
  ENDDO
  !$OMP END DO
 
  IF( ISSLOPE )THEN                                            ! *** if bedslope is calculated
    !$OMP DO PRIVATE(ND,LF,LL,NS,LP,L,UTMP,VTMP)
    DO ND=1,NDM  
      LF=(ND-1)*LDMSED+1  
      LL=MIN(LF+LDMSED-1,LASED)

      DO NS=1,NSCM
        IF( D50(NS) < BEDLOAD_CUTOFF ) CYCLE
        IF( ISKIP(NS) == 0 )THEN
          DO LP=LF,LL
            L = LSED(LP)
            UTMP = UBL(L,NS)                                     ! *** save original x-bedload velocity
            VTMP = VBL(L,NS)                                     ! *** save original x-bedload velocity
            UBL(L,NS) = ALPHA_PX(L)*UBL(L,NS)                    ! *** modify by pitch angle
            VBL(L,NS) = ALPHA_PY(L)*VBL(L,NS)                    ! *** modify by roll angle
            IF( UBL(L,NS)>VBL(L,NS) )THEN                        ! *** find dominant velocity direction
              VBL(L,NS) = VBL(L,NS) + ALPHA_RX(L,NS)*UTMP        ! *** Bedload velocity (x is dominant roll rirection)
              UBL(L,NS) = UBL(L,NS) - ALPHA_RX(L,NS)*VBL(L,NS)   ! *** as impacted by bedslope
              UBL(L,NS) = UBL(L,NS) + ALPHA_RY(L,NS)*VTMP        ! *** (secondary roll due to y)
              VBL(L,NS) = VBL(L,NS) - ALPHA_RY(L,NS)*UBL(L,NS)   ! *** see Lesser (2004) Ikeda (1982)
            ELSE
              UBL(L,NS) = UBL(L,NS) + ALPHA_RY(L,NS)*VTMP        ! *** Bedload velocity (y is dominant roll direction)
              VBL(L,NS) = VBL(L,NS) - ALPHA_RY(L,NS)*UBL(L,NS)   ! *** as impacted by bedslope
              VBL(L,NS) = VBL(L,NS) + ALPHA_RX(L,NS)*UTMP        ! *** (secondary roll due to x)
              UBL(L,NS) = UBL(L,NS) - ALPHA_RX(L,NS)*VBL(L,NS)   ! *** see Lesser (2004) Ikeda (1982)
            ENDIF
          ENDDO
        ENDIF
      ENDDO
    ENDDO
    !$OMP END DO
  ENDIF
     
  ! *** *******************************************************************!
  ! All the equations below are solving the pde in eqn.18.
  !$OMP DO PRIVATE(ND,LF,LL,NS,LP,L,LS,LW)
  DO ND=1,NDM  
    LF=(ND-1)*LDMSED+1  
    LL=MIN(LF+LDMSED-1,LASED)

    ! *** CBL     - Bedload concentration (g/cm^2)     (Original SNL was in g/cm^3)
    ! *** QSBDLDX - Bedload flux in X direction (g/s)  (Original SNL was in g/cm^2)
    ! *** QSBDLDY - Bedload flux in Y direction (g/s)  (Original SNL was in g/cm^2)
    ! *** DZBL    - Bedload (i.e. saltation) height (cm)
    DO NS=1,NSCM
      IF( D50(NS) < BEDLOAD_CUTOFF ) CYCLE
      IF( ISKIP(NS) == 0 )THEN
        DO LP=LF,LL
          L = LSED(LP)
          LS = LSC(L)
          LW = LWC(L)
          
          !  *** X Bedload flux at I-1/2 interface
          IF( UBL(L,NS) == 0. )THEN
            QSBDLDX(L,NS) = 0.
          ELSEIF( UBL(L,NS) > 0. )THEN
            ! *** g/s                cm           g/cm2    cm/s
            QSBDLDX(L,NS) = SUB(L)*DXUCM(LW)*CBL(LW,NS)*UBL(L,NS)    ! *** FLOWING EAST
          ELSE
            QSBDLDX(L,NS) = SUB(L)*DXUCM(L) *CBL(L,NS) *UBL(L,NS)    ! *** FLOWING WEST
          ENDIF
        
          ! *** Y Bedload flux at J-1/2 interface
          IF( VBL(L,NS) == 0. )THEN
            QSBDLDY(L,NS) = 0.
          ELSEIF( VBL(L,NS) > 0. )THEN
            QSBDLDY(L,NS) = SVB(L)*DYVCM(LS)*CBL(LS,NS)*VBL(L,NS)    ! *** FLOWING NORTH
          ELSE
            QSBDLDY(L,NS) = SVB(L)*DYVCM(L) *CBL(L,NS) *VBL(L,NS)    ! *** FLOWING SOUTH
          ENDIF
        ENDDO
      ELSE
        ! *** ZERO THE FLUXES
        DO LP=LF,LL
          L=LSED(LP)
          QSBDLDX(L,NS) = 0.0
          QSBDLDY(L,NS) = 0.0
        ENDDO
      ENDIF
    ENDDO
  ENDDO
  !$OMP END DO
     
#ifdef _MPI
  !$OMP BARRIER
  !$OMP MASTER
  TTDS = DSTIME(0)
  Call MPI_barrier(MPI_Comm_World, ierr)
  TWAIT = DSTIME(0) - TTDS
  TTSED = TTSED - TWAIT

  TTDS = DSTIME(0)
  CALL Communicate_BEDLOAD(1,NSCM)
  DSITIMING(8) = DSITIMING(8) + (DSTIME(0) - TTDS)
  !$OMP END MASTER
  !$OMP BARRIER
#endif                

  ! *** *************************************************************************
  ! *** Transport Equation for bedload concentration (g/cm2)
  !$OMP DO PRIVATE(ND,LF,LL,NS,LP,L,LE,LN)
  DO ND=1,NDM  
    LF=(ND-1)*LDMSED+1  
    LL=MIN(LF+LDMSED-1,LASED)

    DO NS=1,NSCM
      IF( D50(NS) < BEDLOAD_CUTOFF ) CYCLE
      DO LP=LF,LL
        L=LSED(LP)
        LE = LEC(L)
        LN = LNC(L)
        CBL(L,NS) = CBL(L,NS) + ( DXYIPCM(L)*DTSEDJ*( QSBDLDX(L,NS)-QSBDLDX(LE,NS) + QSBDLDY(L,NS)-QSBDLDY(LN,NS) ) + QBLFLUX(L,NS) )
      ENDDO
    ENDDO
  ENDDO
  !$OMP END DO
  !$OMP END PARALLEL

  RETURN 

END SUBROUTINE BEDLOADJ
