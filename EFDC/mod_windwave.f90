! ----------------------------------------------------------------------
!   This file is a part of EFDC+
!   Website:  https://eemodelingsystem.com/
!   Repository: https://github.com/dsi-llc/EFDC_Plus.git
! ----------------------------------------------------------------------
! Copyright 2021-2022 DSI, LLC
! Distributed under the GNU GPLv2 License.
! ----------------------------------------------------------------------
MODULE WINDWAVE

! CHANGE RECORD
! DATE MODIFIED     BY               DESCRIPTION
!----------------------------------------------------------------------!
! 2017-05-23        Dang Chung       IMPROVED WAVE CALCULATION
! 2011-08-19        Paul M. Craig    Added OMP
! 2010-04-26        Dang Chung &     Built the WindWave Sub-Model
!                   Paul M. Craig

USE GLOBAL
Use Allocate_Initialize
USE INFOMOD,ONLY:SKIPCOM
Use MPI
Use Variables_MPI
Use Variables_MPI_Write_Out
Use Broadcast_Routines
Use Variables_MPI_Mapping

IMPLICIT NONE

INTEGER(IK4) ,PARAMETER :: UFET = 214       ! *** FETCH.OUT
INTEGER(IK4) ,PARAMETER :: UWIN = 215       ! *** LIJXY.OUT
INTEGER(IK4) ,PARAMETER :: UTAU = 216       ! *** TAUW.OUT

INTEGER(IK4),PRIVATE,PARAMETER :: NZONE = 16      ! *** NUMBER OF ZONES

REAL(RKD)             :: ROTAT            ! *** COUNTER-CLOCKWISE ROTATION OF DOMAIN [0,360]

REAL(RKD) ,PRIVATE,PARAMETER :: FETANG(NZONE) = (/0.0,22.5,45.0,67.5,90.0,112.5,135.0,157.5,180.0,202.5,225.0,247.5,270.0,292.5,315.0,337.5/)

PRIVATE                      :: FETZONE

CONTAINS

SUBROUTINE WINDWAVETUR
  ! *** Compute the wind wave bed shear  (ISWAVE=3, similar to WAVEBL) 
  ! *** Optionally with induced currents (ISWAVE=4, similar to WAVESXY)
  ! *** These options do not call WAVEBL (ISWAVE=1) or WAVESXY (ISWAVE=2)
  USE GLOBAL
  INTEGER   :: L,ND,LF,LL,LP
  REAL      :: RA,CDTMP,AEXTMP,UWORBIT,VISMUDD,REYWAVE,WVFF
  REAL :: TMPVAL,TAUTMP,CORZBR,CDRGTMP
  REAL,EXTERNAL :: CSEDVIS

  CALL WINDWAVECAL         !OUTPUT: WV(L).HEIGHT,UDEL,WINDDIR,WV.FREQ,RLS

  ! ***  INITIALIZE WAVE-CURRENT BOUNDARY LAYER MODEL CALCULATING
  ! ***  THE WAVE TURBULENT INTENSITY, QQWV
  ! ***  AND SQUARED HORIZONTAL WAVE OBRITAL VELOCITY MAGNITUDE
  ! ***  WAVE REYNOLD NUMBER MUST BE USED TO DISTINGUISH HYRODYNAMIC REGIME

  !$OMP PARALLEL DEFAULT(SHARED)
  !$OMP DO PRIVATE(ND,LF,LL,LP,L)  &
  !$OMP    PRIVATE(UWORBIT,AEXTMP,VISMUDD,REYWAVE,RA,CDTMP,WVFF,TMPVAL,TAUTMP,CORZBR,CDRGTMP)
  DO ND = 1,NDM
    LF = (ND-1)*LDMWET+1
    LL = MIN(LF+LDMWET-1,LAWET)

    DO LP = LF,LL
      L = LWET(LP)
      IF( LWVMASK(L) )THEN
        ! *** SET ZBRE AS NIKURADSE ROUGHNESS
        IF( ISTRAN(7) > 0 )THEN
          ! *** BASE ON NIKURADSE ROUGHNESS (APPROXIMATE 2.5*D50)
          ZBRE(L) = MAX(SEDDIA50(L,KBT(L)),1D-6)*2.5
        ELSE
          ZBRE(L) = KSW
        ENDIF
        IF( WV(L).HEIGHT  >= WHMI .AND. HP(L) > HDRYWAV )THEN
          UWORBIT  = WV(L).UDEL
          AEXTMP   = UWORBIT/WV(L).FREQ
          UWVSQ(L) = UWORBIT*UWORBIT

          IF( UWORBIT < 1.E-6 )THEN
            UWVSQ(L) = 0.
            QQWV1(L) = 0.
            QQWV2(L) = 0.
            CYCLE
          ENDIF

          IF( ISWAVE == 3 )THEN
            VISMUDD = 1.36D-6
            IF( ISMUD  >= 1 ) VISMUDD = CSEDVIS(SED(L,KSZ(L),1))
            REYWAVE = UWORBIT*AEXTMP/VISMUDD
            RA= AEXTMP/ZBRE(L)

            ! *** COMPUTE FRICTION FACTOR DUE TO WAVE: WVFF
            IF( REYWAVE  <= 5D5 )THEN
              ! *** LAMINAR
              WVFF  = 2*REYWAVE**(-0.5)
            ELSEIF( REYWAVE > 5D5 .AND. RA > 1.57 )THEN
              ! *** TURBULENT SMOOTH WAVE BOUNDARY LAYER
              WVFF = 0.09*REYWAVE**(-0.2)
            ELSEIF( REYWAVE > 5D5 .AND. RA  <= 1.57 )THEN
              ! *** TURBULENT ROUGH WAVE BOUNDARY LAYER
              WVFF = EXP(5.2*RA**(-0.19)-6)    ! *** Baird's paper
              WVFF = MIN(WVFF,0.3)
            ENDIF
            CDTMP = 0.5*WVFF
            QQWV1(L) = MIN(CDTMP*UWORBIT*UWORBIT,QQMAX)

          ELSEIF( ISWAVE == 4 )THEN
            ! *** CHECK FOR NON-COHESIVE TRANSPORT
            IF( ISTRAN(7) > 0 )THEN
              TMPVAL = UWORBIT*SQRT( AEXTMP/(30.*ZBRE(L)) )
              TAUTMP = TMPVAL/TAUR(NSED + 1)
              CORZBR = 1. + 1.2*TAUTMP/(1. + 0.2*TAUTMP)
              ZBRE(L) = ZBRE(L)*CORZBR
            ENDIF
            CDRGTMP = (30.*ZBRE(L)/AEXTMP)**0.2
            CDRGTMP = 5.57*CDRGTMP-6.13
            CDRGTMP = EXP(CDRGTMP)
            CDRGTMP = MIN(CDRGTMP,0.22)
            TMPVAL = 0.5*CDRGTMP*UWVSQ(L)
            QQWV2(L) = MIN(CTURB2*TMPVAL,QQMAX)
          ENDIF

        ELSE
          QQWV1(L) = QQLMIN
          QQWV2(L) = QQLMIN
          UWVSQ(L) = 0.
        ENDIF

        WV(L).TWX = RHO*QQWV1(L)*WV(L).TWX   ! *** Bed shear stress due to waves - East
        WV(L).TWY = RHO*QQWV1(L)*WV(L).TWY   ! *** Bed shear stress due to waves - North
      ENDIF
    ENDDO
  ENDDO    ! *** END OF DOMAIN
  !$OMP END DO
  !$OMP END PARALLEL

  ! *** Wave turbulent intensity: QQWV2 similar to ISWAVE = 2
  ! *** To decrease turbulence decrease CTURB (DEFAULT:16.6)

  IF( ISWAVE == 4) CALL W_WAVESXY

  if(process_id == master_id )then
    IF( TIMEDAY  >= SNAPSHOTS(NSNAPSHOTS) .AND. DEBUG )THEN
      OPEN(UTAU,FILE = OUTDIR//'TAUW.OUT',FORM = 'BINARY')
      WRITE(UTAU) (WV(L).HEIGHT,REAL(WV(L).PERIOD,4),REAL(WV(L).LENGTH,4),WV(L).TWX,WV(L).TWY,L = 2,LA)
      CLOSE(UTAU)
    ENDIF
  end if

END SUBROUTINE

SUBROUTINE WINDWAVECAL
  ! *** Calculating wave parameters for every cell using the SMB model using
  ! *** wind parameters from WSER.INP and wind sheltering
  ! ***
  ! *** INPUT:
  ! *** WNDVELE(L), WNDVELN(L), HP(L)
  ! ***
  ! *** OUTPUT:
  ! ***   WV(L).HEIGHT - Wave height (m)
  ! ***   WV(L).DIR    - Wave angle (radians)
  ! ***   WV(L).PERIOD - Wave period (sec)
  ! ***   WV(L).FREQ   - Wave freqency (rad/sec)
  ! ***   WV(L).UDEL   - Maximum orbital velocity
  ! ***   WV(L).TWX    - Surface shear stress in the U direction
  ! ***   WV(L).TWY    - Surface shear stress in the V direction

  INTEGER :: L, ZONE, ND, LF, LL, LP, NH
  REAL(RKD)  :: AVEDEP, FC0, FC1, FC2, FC3, L0, L1, WL0, WL1, FLWET
  REAL(RKD)  :: WINDDIR              ! *** Wind direction in deg [0, 360]
  REAL(RKD)  :: WINX, WINY           ! *** Wind components in X and Y
  REAL(RKD)  :: WINDVEL, WINDVEL2    ! *** Wind magnitudes

  ! *** CALCULATING WAVE HEIGHT,PERIOD,ORBITAL VELOCITY AND LENGTH
  FLWET = FLOAT(LAWET)

  !$OMP PARALLEL DEFAULT(SHARED)

  !$OMP DO PRIVATE(ND, LF, LL, LP, L, NH)  &
  !$OMP    PRIVATE(WINX, WINY, WINDVEL2, WINDVEL, WINDDIR, ZONE, FC0, FC1, FC2, FC3, L0, L1, WL0, WL1)
  DO ND = 1,NDM
    LF = (ND-1)*LDMWET+1
    LL = MIN(LF+LDMWET-1,LAWET)

    DO LP = LF,LL
      L = LWET(LP)
      IF( LWVMASK(L) )THEN
        ! *** 10 meter winds WNDVELE, WNDVELN already adjusted for wind sheltering
        WINX = WNDVELE(L)    ! *** X IS TRUE EAST
        WINY = WNDVELN(L)    ! *** Y IS TRUE NORTH

        WINDVEL2 = WINX*WINX + WINY*WINY
        WINDVEL = SQRT(WINDVEL2)                   ! *** 10m wind magnitude

        IF( HP(L) > HDRY .AND. WINDVEL > 1D-3 )THEN
          WV(L).TWX = WINX/WINDVEL
          WV(L).TWY = WINY/WINDVEL
          IF( WINX  >= 0 )THEN
            WINDDIR  = ACOS(WV(L).TWY)*180./PI      !DEG. (NORTH,WIND TO)
          ELSE
            WINDDIR  = 360-ACOS(WV(L).TWY)*180./PI
          ENDIF
          ZONE = FETZONE(WINDDIR)
          AVEDEP = Fetch_Depth(L,ZONE)                                                 ! *** Get the average depth along the fetch (m)
          
          ! *** Wave height (m)
          FC0 = (G*AVEDEP/WINDVEL2)**0.75
          FC1 = TANH(0.530*FC0)
          FC2 = WINDVEL2*GI*0.283*FC1
          FC3 = TANH(0.0125*(G*FWDIR(L,ZONE)/WINDVEL2)**0.42/FC1)
          WV(L).HEIGHT = MIN(0.75*HP(L), FC2*FC3)                                      ! *** Wave height (m)

          ! *** Vegetation effect    delme - Disable for now.  Add more robust way of treating wave/veg interactions
          !IF( ISVEG > 0 )THEN
          !  IF( MVEGL(L) /= MVEGOW )THEN
          !    WV(L).HEIGHT = 0.
          !  ELSE
          !    IF( (MVEGL(LWC(L)) /= MVEGOW) .OR. &
          !        (MVEGL(LEC(L)) /= MVEGOW) .OR. &
          !        (MVEGL(LSC(L)) /= MVEGOW) .OR. &
          !        (MVEGL(LNC(L)) /= MVEGOW) )       WV(L).HEIGHT = 0.5*WV(L).HEIGHT
          !  ENDIF
          !ENDIF

          ! *** Wave frequency (rad/s)
          FC0 = TANH(0.833*(G*AVEDEP/WINDVEL2)**0.375)
          FC1 = 7.54*WINDVEL*GI*FC0
          FC2 = TANH(0.077*(G*FWDIR(L,ZONE)/WINDVEL2)**0.25/FC0)
          WV(L).PERIOD = MAX(1D-3, FC1*FC2)
          WV(L).FREQ   = 2.0*PI/WV(L).PERIOD

          ! *** Wave length, Hunt approximation (1979) (m)
          FC1 = WV(L).FREQ**2*HP(L)*GI                                                          ! *** EFDC+ Eq. 2.55
          FC2 = FC1 + 1.0/( 1.0 + 0.6522*FC1 + 0.4622*FC1**2 + 0.0864*FC1**4 + 0.0675*FC1**5 )  ! *** EFDC+ Eq. 2.54
          WV(L).LENGTH = WV(L).PERIOD*SQRT(G*HP(L)/FC2)                                         ! *** EFDC+ Eq. 2.53

          ! *** Orbital velocity (m/s)
          WV(L).K = MAX( 2.*PI/WV(L).LENGTH, 0.01 )
          WV(L).KHP = MIN(WV(L).K*HP(L),SHLIM)
          WV(L).UDEL = MAX(1D-6, PI*WV(L).HEIGHT/( WV(L).PERIOD*SINH(WV(L).KHP) ))              ! *** Orbital velocity    Eq. 2.59

          ! *** Wave direction (radians) counter-clockwise (cell-east axis,wave)
          WINX =  CVN(L)*WNDVELE(L) - CVE(L)*WNDVELN(L)                                         ! *** Curvilinear system
          WINY = -CUN(L)*WNDVELE(L) + CUE(L)*WNDVELN(L)
          WV(L).DIR= ATAN2(WINY,WINX)

        ELSE
          WV(L).HEIGHT = 0.0
          WV(L).HEISIG = 0.0
          WV(L).DIR    = 0.0
          WV(L).FREQ   = 1.0
          WV(L).LENGTH = 0.0
          WV(L).UDEL   = 0.0
          WV(L).PERIOD = 0.0
          WV(L).K      = 0.01
        ENDIF
      ENDIF  ! *** END OF VALID WAVE CELL

    ENDDO
  ENDDO    ! *** END OF DOMAIN
  !$OMP END DO

  !$OMP END PARALLEL

END SUBROUTINE

FUNCTION FETZONE8(WINDDIR) RESULT(ZONE)
  ! * DETERMINING FETCH ZONE AND FETCH MAIN ANGLE
  ! * BASED ON THE GIVEN WIND DIRECTION WINDDIR
  ! * WINDDIR     : INTERPOLATED WIND DIRECTION FROM WSER.INP
  ! * UNIT     : [0,360]
  ! * FORMATION: ANGLE BY (NORTH,WIND TO)IN CLOCKWISE DIRECTION
  ! * ZONE 1: NORTH        > 337.5 OR   <= 22.5
  ! * ZONE 2: NORTH-EAST   > 22.5  OR   <= 67.5
  ! * ZONE 3: EAST         > 
  ! * ZONE 4: SOUTH-EAST
  ! * ZONE 5: SOUTH
  ! * ZONE 6: SOUTH-WEST
  ! * ZONE 7: WEST
  ! * ZONE 8: NORTH-WEST
  REAL(RKD) ,INTENT(IN ) :: WINDDIR   ![0,360]
  INTEGER :: ZONE

  IF( WINDDIR > 337.5 .OR. WINDDIR  <= 22.5 )THEN
    ZONE = 1
  ELSEIF( WINDDIR > 22.5 .AND. WINDDIR  <= 67.5 )THEN
    ZONE = 2
  ELSEIF( WINDDIR > 67.5 .AND. WINDDIR  <= 112.5 )THEN
    ZONE = 3
  ELSEIF( WINDDIR > 112.5 .AND. WINDDIR  <= 157.5 )THEN
    ZONE = 4
  ELSEIF( WINDDIR > 157.5 .AND. WINDDIR  <= 202.5 )THEN
    ZONE = 5
  ELSEIF( WINDDIR > 202.5 .AND. WINDDIR  <= 247.5 )THEN
    ZONE = 6
  ELSEIF( WINDDIR > 247.5 .AND. WINDDIR  <= 292.5 )THEN
    ZONE = 7
  ELSEIF( WINDDIR > 292.5 .AND. WINDDIR  <= 337.5 )THEN
    ZONE = 8
  ENDIF
END FUNCTION

REAL FUNCTION Fetch_Depth(L,NZ)
  ! *** Compute the average depth of wet cells along the fetch

  INTEGER,INTENT(IN) :: L, NZ
  INTEGER :: ICELL, LF, NF
  REAL :: DEPTH
 
  DEPTH = 0.0
  NF = 0
  DO ICELL = 1, LWDIR(L,NZ,0)
    LF = LWDIR(L,NZ,ICELL)
    IF( HP(LF) < HDRY ) CYCLE                            ! *** Ignore dry cells and exit
    NF = NF + 1
    DEPTH = DEPTH + HP(LF)
  ENDDO 
  Fetch_Depth = DEPTH/FLOAT(NF)
  
END FUNCTION Fetch_Depth

FUNCTION FETZONE(WINDDIR) RESULT(ZONE)
  ! *** DETERMINING FETCH ZONE AND FETCH MAIN ANGLE
  ! *** BASED ON THE GIVEN WIND DIRECTION WINDDIR
  ! *** WINDDIR     : INTERPOLATED WIND DIRECTION FROM WSER.INP
  ! *** UNIT     : [0,360]
  ! *** FORMATION: ANGLE BY (NORTH,WIND TO)IN CLOCKWISE DIRECTION
  REAL(RKD) ,INTENT(IN ) :: WINDDIR   ![0,360]
  INTEGER :: ZONE

  IF( WINDDIR > 348.75 .OR. WINDDIR  <= 11.25 )THEN
    ZONE = 1
  ELSEIF( WINDDIR >  11.25 .AND. WINDDIR  <=  33.75 )THEN
    ZONE = 2                            
  ELSEIF( WINDDIR >  33.75 .AND. WINDDIR  <=  56.25 )THEN
    ZONE = 3                            
  ELSEIF( WINDDIR >  56.25 .AND. WINDDIR  <=  78.75 )THEN
    ZONE = 4            
  ELSEIF( WINDDIR >  78.75 .AND. WINDDIR  <= 101.25 )THEN
    ZONE = 5
  ELSEIF( WINDDIR > 101.25 .AND. WINDDIR  <= 123.75 )THEN
    ZONE = 6
  ELSEIF( WINDDIR > 123.75 .AND. WINDDIR  <= 146.25 )THEN
    ZONE = 7
  ELSEIF( WINDDIR > 146.25 .AND. WINDDIR  <= 168.75 )THEN
    ZONE = 8
  ELSEIF( WINDDIR > 168.75 .AND. WINDDIR  <= 191.25 )THEN
    ZONE = 9
  ELSEIF( WINDDIR > 191.25 .AND. WINDDIR  <= 213.75 )THEN
    ZONE = 10
  ELSEIF( WINDDIR > 213.75 .AND. WINDDIR  <= 236.25 )THEN
    ZONE = 11
  ELSEIF( WINDDIR > 236.25 .AND. WINDDIR  <= 258.75 )THEN
    ZONE = 12
  ELSEIF( WINDDIR > 258.75 .AND. WINDDIR  <= 281.25 )THEN
    ZONE = 13
  ELSEIF( WINDDIR > 281.25 .AND. WINDDIR  <= 303.75 )THEN
    ZONE = 14
  ELSEIF( WINDDIR > 303.75 .AND. WINDDIR  <= 326.25 )THEN
    ZONE = 15
  ELSEIF( WINDDIR > 326.25 .AND. WINDDIR  <= 348.75 )THEN
    ZONE = 16
  ENDIF
END FUNCTION

SUBROUTINE FETCH_Global
  ! *** DETERMINING THE FETCH FOR EACH CELL:
  ! *** OUTPUT: FWDIR(2:LA,1:NZONE) IN M
  USE DRIFTER,ONLY:INSIDECELL_GL
  REAL(RKD) :: AL(NZONE), RL, XM, YM, RL0, DOTX, DOTY
  INTEGER   :: I, J, LG, LL, LM, LE, LN, LS, LW, NZ, NCELLS, IM, JM, STATUS
  LOGICAL   :: ULOG, VLOG

  AL  = (90_8 - FETANG - ROTAT)*PI/180._8                                          ! *** Angle (trig) to check fetch moving up the wind fetch (away from the cell).  Fetch angle the direction wind is coming from
  AL  = PI + AL                                                                    ! *** Angle (trig) to check fetch moving up the wind fetch (away from the cell).  Fetch angle the direction wind is coming from
  RL0 = 0.25*MIN(MINVAL(DXP_Global(2:LA_Global)),MINVAL(DYP_Global(2:LA_Global)))  ! *** Distance increment to seach along the fetch.  MIN(DX,DY)/4

  DO LG = 2, LA_GLOBAL
    IF( LWVMASK_Global(LG) )THEN
      DO NZ = 1, NZONE
        RL = 0
        IM = IL_GL(LG)
        JM = JL_GL(LG)
        
        LL = 0
        NCELLS = 1
        LWDIR_Global(LG,NZ,NCELLS) = LG        ! *** Current cell is always included in fetch
        
        ! *** Search for the 9 cells around the current fetch endpoint
        LOOP1:DO WHILE(1)
          STATUS = 0
          RL = RL + RL0                                    ! *** Current fetch
          XM = XCOR_Global(LG,5) + RL*COS(AL(NZ))          ! *** X coordinate in global model coordinate system
          YM = YCOR_Global(LG,5) + RL*SIN(AL(NZ))          ! *** Y coordinate in global model coordinate system
          
          ! *** Search a radius +/- one cell around the current cell to find an adjacent cell
          LOOP2:DO J = JM-1,JM + 1
            IF ( J < 1 ) CYCLE
            
            DO I = IM-1,IM + 1
              IF ( I < 1 ) CYCLE
              
              ! *** Found an adjacent cell.  Check if XM,YM are contained in the cell
              LM = LIJ_GLOBAL(I,J)
              IF( LM < 2 ) CYCLE
              IF( INSIDECELL_GL(LM,XM,YM) )THEN
                ! *** Found a cell along the fetch
                LL = LM
                
                ! *** Build list of unique cells along fetch
                IF( LWDIR_Global(LG,NZ,NCELLS) /= LM )THEN
                  NCELLS = NCELLS + 1
                  LWDIR_Global(LG,NZ,NCELLS) = LM
                ENDIF

                ! *** Now check for masks
                DOTX = CUE_Global(LG)*COS(AL(NZ)) + CUN_Global(LG)*SIN(AL(NZ))
                DOTY = CVE_Global(LG)*COS(AL(NZ)) + CVN_Global(LG)*SIN(AL(NZ))
                IF( ABS(DOTX) < 0.001_8 )THEN
                  DOTX = 0
                  DOTY = 1.0
                ENDIF
                IF( ABS(DOTX) > 0.999_8 )THEN
                  DOTX = 1.0
                  DOTY = 0
                ENDIF
                IF( ABS(DOTY) < 0.001_8 )THEN
                  DOTX = 1.0
                  DOTY = 0
                ENDIF
                IF( ABS(DOTY) > 0.999_8 )THEN
                  DOTX = 0
                  DOTY = 1.0
                ENDIF

                LW = LWC_Global(LM)
                LE = LEC_Global(LM)
                LS = LSC_Global(LM)
                LN = LNC_Global(LM)
                
                ! ***            1    2    3    4    5     6     7     8     9   10     11    12    13    14    15    16
                ! *** FETANG = 0.0,22.5,45.0,67.5,90.0,112.5,135.0,157.5,180.0,202.5,225.0,247.5,270.0,292.5,315.0,337.5
                IF( NZ == 1 )THEN
                  ULOG = ABS(DOTX) /= 1.0 .AND. (VMASK_Global(LM) == 1)
                  VLOG = ABS(DOTY) /= 1.0 .AND. (UMASK_Global(LM) == 1 .OR. UMASK_Global(LE) == 1)
                ELSEIF( NZ > 1 .AND. NZ  <= 4 )THEN
                  ULOG = ABS(DOTX) /= 1.0 .AND. (VMASK_Global(LM) == 1 .OR. VMASK_Global(LW) == 1)
                  VLOG = ABS(DOTY) /= 1.0 .AND. (UMASK_Global(LM) == 1 .OR. UMASK_Global(LS) == 1)
                ELSEIF( NZ == 5 )THEN
                  ULOG = ABS(DOTX) /= 1.0 .AND. (VMASK_Global(LM) == 1 .OR. VMASK_Global(LN) == 1)
                  VLOG = ABS(DOTY) /= 1.0 .AND. (UMASK_Global(LM) == 1)
                ELSEIF( NZ > 5 .AND. NZ  <= 8 )THEN
                  ULOG = ABS(DOTX) /= 1.0 .AND. (VMASK_Global(LN) == 1 .OR. VMASK_Global(LWC_Global(LN)) == 1)
                  VLOG = ABS(DOTY) /= 1.0 .AND. (UMASK_Global(LM) == 1 .OR. UMASK_Global(LN) == 1)
                ELSEIF( NZ == 9 )THEN
                  ULOG = ABS(DOTX) /= 1.0 .AND. (VMASK_Global(LN) == 1)
                  VLOG = ABS(DOTY) /= 1.0 .AND. (UMASK_Global(LM) == 1 .OR. UMASK_Global(LE) == 1)
                ELSEIF( NZ > 9 .AND. NZ  <= 12 )THEN
                  ULOG = ABS(DOTX) /= 1.0 .AND. (VMASK_Global(LN) == 1 .OR. VMASK_Global(LEC_Global(LN)) == 1)
                  VLOG = ABS(DOTY) /= 1.0 .AND. (UMASK_Global(LE) == 1 .OR. UMASK_Global(LEC_Global(LN)) == 1)
                ELSEIF( NZ == 13 )THEN
                  ULOG = ABS(DOTX) /= 1.0 .AND. (VMASK_Global(LM) == 1 .OR. VMASK_Global(LN) == 1)
                  VLOG = ABS(DOTY) /= 1.0 .AND. (UMASK_Global(LE) == 1)
                ELSEIF( NZ > 13 .AND. NZ  <= 16 )THEN
                  ULOG = ABS(DOTX) /= 1.0 .AND. (VMASK_Global(LM) == 1 .OR. VMASK_Global(LE) == 1)
                  VLOG = ABS(DOTY) /= 1.0 .AND. (UMASK_Global(LE) == 1 .OR. UMASK_Global(LEC_Global(LS)) == 1)
                ENDIF

                IF( ULOG .OR. VLOG )THEN
                  EXIT LOOP1           ! *** Found a mask in either the U or V face that blocks waves.  End fetch
                ELSE
                  STATUS = 1           ! *** Fetch is inside the cell LM and LM has not changed
                ENDIF
                EXIT LOOP2
              ELSE
                LM = 0                 ! ***  Fetch not found in cell LM
              ENDIF
            ENDDO
          ENDDO LOOP2
          IF( STATUS == 0 )THEN
            EXIT LOOP1                 ! *** Found edge of domain.  End fetch
          ENDIF
          IM = IL_GL(LM)
          JM = JL_GL(LM)
        ENDDO LOOP1

        LWDIR_Global(LG,NZ,0) = NCELLS
        FWDIR_Global(LG,NZ)   = RL
      ENDDO
    ENDIF
  ENDDO

  ! *** Convert to wind direction from
  DO NZ = 1,NZONE
    AL(NZ) = FETANG(NZ) - 180.
    IF( AL(NZ) < 0. ) AL(NZ) = AL(NZ) + 360.
  ENDDO
  
  ! *** Save the fetch out to a file
  OPEN(UFET,FILE = OUTDIR//'FETCH.OUT')
  WRITE(UFET,'(15X,A7,16F15.1)') 'Angle: ', (AL(NZ),NZ = 1,NZONE)
  DO LG = 2,LA_GLOBAL
    WRITE(UFET,'(I10,2I6,16F15.4)') LG, IL_GL(LG), JL_GL(LG), (FWDIR_Global(LG,NZ),NZ = 1,NZONE)
  ENDDO
  CLOSE(UFET)

END SUBROUTINE FETCH_Global


SUBROUTINE WINDWAVEINIT
  ! *** INITIALIZES WAVE VARIABLES AND GENERATES FETCH.OUT
  USE GLOBAL
  INTEGER    :: L, K, LG, LL, NZ, NF, LGF, LLF
  INTEGER(4) :: IERR = 0     ! <  local MPI error flag

  Call AllocateDSI(LWVMASK_Global, LCM_GLobal, .false.)
  Call AllocateDSI(FWDIR_Global,   LCM_GLobal, 16, 0.0)
  Call AllocateDSI(LWDIR_Global,   LCM_GLobal, 16, -(IC_Global+JC_Global), 0)
  
  RSWRSR = FLOAT(ISWRSR)
  RSWRSI = FLOAT(ISWRSI)
  ROTAT   = 0
  WACCWE  = 0
  FWVTP   = 0

  ! *** Wave Computational Cell Defaults
  NWVCELLS = LA-1
  DO L = 2,LA
    LWVCELL(L-1) = L
    LWVMASK(L) = .TRUE.
  ENDDO
  DO L = 2,LCM_GLobal
    LWVMASK_Global(L) = .TRUE.
  ENDDO

  ! *** READ IN WAVE COMPUTATIONAL CELL LIST
  IF( IUSEWVCELLS /= 0 )THEN
    CALL READWAVECELLS
  ENDIF

  KSW = MAX(1D-6,KSW)

  if(process_id == master_id )then
    WRITE(*,'(A)')'COMPUTING FETCH'
    CALL FETCH_Global
  end if

  Call MPI_Barrier(comm_2d, ierr)
  Call Broadcast_Array(FWDIR_Global, master_id)

  ! *** Map to Local Domain
  DO LG = 2,LA_GLOBAL
    L = Map2Local(LG).LL
    IF( L > 0 )THEN
      DO NZ = 1,NZONE
        FWDIR(L,NZ) = FWDIR_Global(LG,NZ)
        
        ! *** Map the fetch cell list
        DO NF = 1, LWDIR_Global(LG,NZ,0)
          LGF = LWDIR_Global(LG,NZ,NF)
          LLF = Map2Local(LGF).LL
          IF( LLF == 0 ) EXIT
          LWDIR(L,NZ,NF) = LLF
        ENDDO
        LWDIR(L,NZ,0) = NF - 1
      ENDDO
    ENDIF
  ENDDO

  !CALL FETCH

  ! >  @todo do we need to write these out on all processes
  if(process_id == master_id )then
    OPEN(UWIN,FILE = OUTDIR//'LIJXY.OUT',ACTION = 'WRITE')
    DO L = 2,LA
      WRITE(UWIN,'(3I10,2F15.6)') L, IL(L), JL(L), DLON(L), DLAT(L)
    ENDDO
    CLOSE(UWIN)
  end if

  JSWRPH = 1

  CALL ZEROWAVE

  ITWCBL1 = 1
  ITWCBL2 = 0
  ITWCBL3 = 0

  ! *** *************************************************************
  !OPEN(1,FILE = 'WAVE.INP',STATUS = 'UNKNOWN')
  !READ(1,*,IOSTAT = ISO)NWVCELLS,WVPRD,ISWCBL,ISWRSR,ISWRSI,NWUPDT, &
  !    NTSWV,WVDISV,WVDISH,WVLSH,WVLSX,ISWVSD,ISDZBR

  !---------------------------------------------------------------
  ! **  INITIALIZE VERTICAL DISTRIBUTION OF WAVE DISSIPATION AS SOURCE
  ! **  TO VERTICAL TKE CLOSURE
  IF( KC == 2 )THEN
    WVDTKEM(1) = WVDISV
    WVDTKEP(1) = WVDISV
  ENDIF
  IF( KC == 3 )THEN
    WVDTKEM(1) = WVDISV
    WVDTKEP(1) = 0.5*WVDISV
    WVDTKEM(2) = 0.5*WVDISV
    WVDTKEP(2) = WVDISV
  ENDIF
  IF( KC >= 4 )THEN
    WVDTKEM(1) = WVDISV
    WVDTKEP(1) = 0.5*WVDISV
    WVDTKEM(KS) = 0.5*WVDISV
    WVDTKEP(KS) = WVDISV
    DO K = 2,KS-1
      WVDTKEM(K) = 0.5*WVDISV
      WVDTKEP(K) = 0.5*WVDISV
    ENDDO
  ENDIF

  DO L = 1,LC
    ZBRE(L) = KSW  ! *** INPUT NIKURADSE ROUGHNESS
  ENDDO

END SUBROUTINE

SUBROUTINE ZEROWAVE
  INTEGER :: L,K
  DO L = 1,LC
    HMPW(L) = 0.
    HMUW(L) = 0.
    HMVW(L) = 0.
    WVKHC(L) = 0.
    WVKHU(L) = 0.
    WVKHV(L) = 0.
    WVTMP1(L) = 0.
    WVTMP2(L) = 0.
    WVTMP3(L) = 0.
    WVTMP4(L) = 0.
    WVENEP(L) = 0.
    UWVSQ(L) = 0.
    QQWC(L) = 1.E-12   ! *** NOT USED
    QQWCR(L) = 1.E-12
    QQWV1(L) = 1.E-12  ! *** BED TURBULENT INTENSITY DUE TO WAVES ONLY
    QQWV2(L) = 0.      ! *** WATER COLUMN TURBULENT INTENSITY DUE TO WAVES
    QQWV3(L) = 1.E-12  ! *** WATER COLUMN TURBULENT INTENSITY DUE TO WAVES MODIFIED FOR NON-COHESIVE MOVING BED
    WV(L).HEIGHT = 0.
    WV(L).K = 0.
    WV(L).DIR = 0.
  ENDDO
  DO K = 1,KC
    DO L = 1,LC
      WVHUU(L,K) = 0.
      WVHVV(L,K) = 0.
      WVHUV(L,K) = 0.
      WVPP(L,K) = 0.
      WVPU(L,K) = 0.
      WVPV(L,K) = 0.
      WV(L).DISSIPA(K) = 0.
      FXWAVE(L,K) = 0.
      FYWAVE(L,K) = 0.
    ENDDO
  ENDDO
END SUBROUTINE

! **********************************************************************************************
! *** Subroutine to compute wind wave generated currents
! ***
SUBROUTINE W_WAVESXY
  REAL :: DISPTMP
  REAL :: TMPVAL,WVWHAUT,WVWHAVT
  REAL(RKD) :: SNHTOPU,SNHBOTU,SNHTOPV,SNHBOTV,TMPPU,TMPPV,TMP
  REAL(RKD) :: WG,WN,WK,RKHM1,RKHM2,TMPP1,TMPP2
  REAL(RKD) :: COSH3,RATIO,ZTOP,ZBOT,COSHTOP,COSHBOT,SINHTOP,SINHBOT,SINH2

  INTEGER :: K,L,LS,LW,LE,LSW,LN,LNW,LSE,ND,LF,LL,LP

  !$OMP PARALLEL DEFAULT(SHARED)
  !$OMP DO PRIVATE(ND,LF,LL,LP,L,DISPTMP,WK,WG,WN)
  DO ND = 1,NDM
    LF = (ND-1)*LDMWET+1
    LL = MIN(LF+LDMWET-1,LAWET)

    DO LP = LF,LL
      L = LWET(LP)
      IF( LWVMASK(L) )THEN
        IF( WV(L).HEIGHT  >= WHMI .AND. HP(L) > HDRYWAV )THEN
          WVENEP(L)= G*WV(L).HEIGHT**2./16.                         ! *** ENERGY/RHO (M3/S2) FOR RANDOM WAVE
          DISPTMP =  0.25*G*WV(L).HEIGHT**2./WV(L).PERIOD           ! *** ENERGY DISSIPATION DUE TO BREAKING WAVE
          WV(L).DISSIPA(KC)= 0.01*DISPTMP
          WK = 2.0*WV(L).KHP
          WG = WK/SINH(WK)
          WN = (WG + 1)/2
          WVHUU(L,KC) = WVENEP(L)*(WG/2 + WN*COS(WV(L).DIR)**2)     ! *** SXXTMP (M3/S2)
          WVHVV(L,KC) = WVENEP(L)*(WG/2 + WN*SIN(WV(L).DIR)**2)     ! *** SYYTMP (M3/S2)
          WVHUV(L,KC) = WVENEP(L)*WN/2*SIN(2*WV(L).DIR)             ! *** SXYTMP (M3/S2)
          HMPW(L) = HP(L) + WV(L).HEIGHT
        ELSE
          WVENEP(L) = 0
          WV(L).DISSIPA(KC) = 0
          WVHUU(L,KC) = 0.0
          WVHVV(L,KC) = 0.0
          WVHUV(L,KC) = 0.0
          HMPW(L) =HP(L)
        ENDIF
      ENDIF
    ENDDO
  ENDDO    ! *** END OF DOMAIN
  !$OMP END DO

  ! *** COMPUTE THE DERIVED WATER SURFACES
  !$OMP DO PRIVATE(ND,LF,LL,LP,L,LS,LW,LSW)
  DO ND = 1,NDM
    LF = (ND-1)*LDMWET+1
    LL = MIN(LF+LDMWET-1,LAWET)

    DO LP = LF,LL
      L = LWET(LP)
      IF( LWVMASK(L) )THEN
        LS = LSC(L)
        LW = LWC(L)
        LSW = LSWC(L)
        HMUW(L) = 0.5*(DXYP(L)*HMPW(L) + DXYP(LW)*HMPW(LW))/(DXU(L)*DYU(L))
        HMVW(L) = 0.5*(DXYP(L)*HMPW(L) + DXYP(LS)*HMPW(LS))/(DXV(L)*DYV(L))
      ENDIF
    ENDDO
  ENDDO    ! *** END OF DOMAIN
  !$OMP END DO

  ! *** DISTRIBUTE VALUES ACROSS KC
  !$OMP DO PRIVATE(ND,LF,LL,LP,L,K) &
  !$OMP    PRIVATE(RKHM1,RKHM2,SINH2,COSH3,RATIO,ZTOP,ZBOT)  &
  !$OMP    PRIVATE(SINHTOP,SINHBOT,COSHTOP,COSHBOT,TMPVAL,TMP,TMPP1,TMPP2)
  DO ND = 1,NDM
    LF = (ND-1)*LDMWET+1
    LL = MIN(LF+LDMWET-1,LAWET)

    DO LP = LF,LL
      L = LWET(LP)
      IF( LWVMASK(L) )THEN
        IF( WV(L).HEIGHT  >= WHMI .AND. HP(L) > HDRY )THEN
          RKHM1 = WV(L).KHP
          RKHM2 = 2.*RKHM1
          SINH2 = SINH(RKHM2)
          COSH3 = COSH(RKHM1)
          RATIO = 0.5 + (RKHM1/SINH2)
          DO K = KSZ(L),KC
            ZTOP = Z(L,K)
            ZBOT = Z(L,K-1)
            ! *** START Moved to after ZTOP is defined (2009_09_03)
            SINHTOP = SINH(RKHM2*ZTOP)
            SINHBOT = SINH(RKHM2*ZBOT)
            COSHTOP = COSH(RKHM1*ZTOP)
            COSHBOT = COSH(RKHM1*ZBOT)
            TMPVAL = (RKHM2*(ZTOP-ZBOT) + SINHTOP-SINHBOT)/(RKHM2 + SINH2)

            ! *** APPLY FACTOR
            WVHUU(L,K) = TMPVAL*WVHUU(L,KC)
            WVHVV(L,K) = TMPVAL*WVHVV(L,KC)
            WVHUV(L,K) = TMPVAL*WVHUV(L,KC)
            WV(L).DISSIPA(K) = TMPVAL*WV(L).DISSIPA(KC)

            TMPP1 = -0.5*(ZTOP-ZBOT) + (ZTOP*COSHTOP-ZBOT*COSHBOT)/COSH3
            TMP = SINH2-2.
            IF( ABS(TMP) < 1D-3 ) TMP = SIGN(1D-3,TMP)
            TMPP2 = (RATIO-1.)*(SINHTOP-SINHBOT-2.*(ZTOP-ZBOT))/TMP

            ! *** LIMIT RANGE WHEN WV.K~0.72
            IF( ABS(TMPP1) > 0.5 )THEN
              TMPP1 = SIGN(0.5,TMPP1)
            ENDIF
            IF( ABS(TMPP2) > 0.5 )THEN
              TMPP2 = SIGN(0.5,TMPP2)
            ENDIF
            WVPP(L,K) = WVENEP(L)*(TMPP1 + TMPP2)
          ENDDO
        ELSE
          WVHUU(L,1:KC) = 0
          WVHVV(L,1:KC) = 0
          WVHUV(L,1:KC) = 0
          WV(L).DISSIPA(1:KC) = 0
          WVPP(L,1:KC) = 0
        ENDIF
      ENDIF
    ENDDO
  ENDDO    ! *** END OF DOMAIN
  !$OMP END DO

  ! **  The Updated of QQWV2 was moved to CALTBXY

  !IF(ISRESTI/ = 0 )THEN
  !  !$OMP SINGLE
  !  WRITE(*,'(A)')'WAVE: WVQWCP.INP'
  !  OPEN(1,FILE = 'wvqwcp.inp',STATUS = 'UNKNOWN')
  !  DO L = 2,LA
  !    READ(1,*)IDUM,JDUM,QQWV1(L),QQWV2(L),QQWV2(L),QQWC(L),QQWCR(L)
  !  ENDDO
  !  !$OMP END SINGLE
  !ENDIF

  ! **  COMPUTE CELL FACE QUANTITIES WVPU,WVPV
  !$OMP DO PRIVATE(ND,LF,LL,LP,L)
  DO ND = 1,NDM
    LF = (ND-1)*LDMWET+1
    LL = MIN(LF+LDMWET-1,LAWET)

    DO LP = LF,LL
      L = LWET(LP)
      IF( LWVMASK(L) )THEN
        IF( WV(L).HEIGHT  >= WHMI .AND. HP(L) > HDRY )THEN
          WVKHU(L) = MIN(HMUW(L)*WV(L).K,SHLIM)
          WVKHV(L) = MIN(HMVW(L)*WV(L).K,SHLIM)
        ELSE
          WVKHU(L) = 1.D-12
          WVKHV(L) = 1.D-12
        ENDIF
      ENDIF
    ENDDO
  ENDDO    ! *** END OF DOMAIN
  !$OMP END DO

  !$OMP DO PRIVATE(ND,LF,LL,LP,L,LS)  &
  !$OMP    PRIVATE(TMPVAL,WVWHAUT,WVWHAVT)
  DO ND = 1,NDM
    LF = (ND-1)*LDMWET+1
    LL = MIN(LF+LDMWET-1,LAWET)

    DO LP = LF,LL
      L = LWET(LP)
      IF( LWVMASK(L) )THEN
        TMPVAL    = 0.5*WV(L).FREQ*WV(L).FREQ
        WVTMP1(L) = MAX(SINH(WVKHU(L)),1D-6)
        WVWHAUT   = (WV(L).HEIGHT + SUB(L)*WV(LWC(L)).HEIGHT)/(1. + SUB(L))
        WVTMP2(L) = TMPVAL*WVWHAUT*WVWHAUT/(WVTMP1(L)*WVTMP1(L))
        WVWHAVT   = (WV(L).HEIGHT + SVB(L)*WV(LSC(L)).HEIGHT)/(1. + SVB(L))
        WVTMP3(L) = MAX(SINH(WVKHV(L)),1D-6)
        WVTMP4(L) = TMPVAL*WVWHAVT*WVWHAVT/(WVTMP3(L)*WVTMP3(L))
      ENDIF
    ENDDO
  ENDDO    ! *** END OF DOMAIN
  !$OMP END DO

  !$OMP DO PRIVATE(ND,K,LP,L)  &
  !$OMP    PRIVATE(ZTOP,ZBOT,SNHTOPU,SNHBOTU,SNHTOPV,SNHBOTV,TMPPU,TMPPV)
  DO ND = 1,NDM
    DO K = 1,KC
      DO LP = 1,LLWET(K,ND)
        L = LKWET(LP,K,ND)
        IF( LWVMASK(L) )THEN
          ZTOP = Z(L,K)
          ZBOT = Z(L,K-1)
          SNHTOPU = SINH(WVKHU(L)*ZTOP)
          SNHBOTU = SINH(WVKHU(L)*ZBOT)
          SNHTOPV = SINH(WVKHV(L)*ZTOP)
          SNHBOTV = SINH(WVKHV(L)*ZBOT)
          TMPPU = (1.-ZTOP)*SNHTOPU*(ZTOP*WVTMP1(L)-SNHTOPU)-(1.-ZBOT)*SNHBOTU*(ZBOT*WVTMP1(L)-SNHBOTU)
          TMPPV = (1.-ZTOP)*SNHTOPV*(ZTOP*WVTMP3(L)-SNHTOPV)-(1.-ZBOT)*SNHBOTV*(ZBOT*WVTMP3(L)-SNHBOTV)
          WVPU(L,K) = WVTMP2(L)*TMPPU
          WVPV(L,K) = WVTMP4(L)*TMPPV
        ENDIF
      ENDDO
    ENDDO
  ENDDO    ! *** END OF DOMAIN
  !$OMP END DO

  ! **  CALCULATE THE NET X AND  Y WAVE REYNOLDS STRESS FORCINGS
  !$OMP DO PRIVATE(ND,K,LP,L,LW,LE,LS,LN,LNW,LSE)
  DO ND = 1,NDM
    DO K = 1,KC
      DO LP = 1,LLWET(K,ND)
        L = LKWET(LP,K,ND)
        IF( LWVMASK(L) )THEN
          LW = LWC(L)
          LE = LEC(L)
          LS = LSC(L)
          LN = LNC(L)
          LNW = LNWC(L)
          LSE = LSEC(L)
          FXWAVE(L,K) = DZIC(L,K)*SUB(L)*SPB(L) * &
            ( RSWRSI*(DYU(L)*(WVPP(L,K) - WVPP(LW,K))         + DYU(L)*WVPU(L,K)*(HMPW(L) - HMPW(LW)))   &
            +RSWRSR*(DYP(L)*WVHUU(L,K) - DYP(LW)*WVHUU(LW,K) + 0.5*(DXV(LN) + DXV(LNW))*WVHUV(LN,K)     &
            -0.5*(DXV(L) + DXV(LW))*WVHUV(L,K)) )
          FYWAVE(L,K) = DZIC(L,K)*SVB(L)*SPB(L) * &
            ( RSWRSI*(DXV(L)*(WVPP(L,K) - WVPP(LS,K))         + DXV(L)*WVPV(L,K)*(HMPW(L) - HMPW(LS )))  &
            +RSWRSR*(DXP(L)*WVHVV(L,K) - DXP(LS)*WVHVV(LS,K) + 0.5*(DYU(LE) + DYU(LSE))*WVHUV(LE,K)     &
            -0.5*(DYU(L) + DYU(LS))*WVHUV(L,K)) )
        ENDIF
      ENDDO
    ENDDO
  ENDDO    ! *** END OF DOMAIN
  !$OMP END DO
  !$OMP END PARALLEL

END SUBROUTINE

SUBROUTINE READWAVECELLS
  ! *** READS THE FILE WAVECELLS.INP TO DEFINE A SUBSET OF CELLS TO USE FOR WAVE COMPUTATIONS
  !

  INTEGER :: L, IWV, JWV, ISO, NWV
  Integer :: NWVCELLS_local, l_local

  Allocate(LWVCELL_Global(LCM_Global))

  ! *** DEFAULT IS OFF
  NWVCELLS = 0
  DO NWV = 1,LA
    LWVMASK(NWV) = .FALSE.
    LWVCELL(NWV) = 0
  ENDDO
  LWVMASK_Global = .FALSE.

  ! *** Do reading only on master process
  if(process_id == master_id )then
    ! *** READ THE WAVE COMPUTATIONAL CELL LIST
    WRITE(*,'(A)')'READING WAVECELLS.INP'
    OPEN(1,FILE = 'wavecells.inp',STATUS = 'OLD')

    ! *** SKIP HEADERS, IF ANY
    CALL SKIPCOM(1,'*')

    ! *** LOOP OVER THE CELLS
    DO NWV = 2,LA
      READ(1,*,IOSTAT = ISO,END = 1000) IWV, JWV
      IF( ISO > 0 ) GOTO 9000

      L = LIJ_Global(IWV,JWV)

      IF( L > 1 )THEN
        NWVCELLS = NWVCELLS + 1
        LWVCELL_Global(NWVCELLS) = L
        LWVMASK_Global(L) = .TRUE.
      ENDIF
    ENDDO

1000 CLOSE(1)
  end if ! *** end on master process

  ! *** Send to all processes
  Call Broadcast_Array(LWVCELL_Global, master_id) ! Not sure we need this
  Call Broadcast_Array(LWVMASK_Global, master_id)

  ! *** Map wave cells to each process
  NWVCELLS_local = 0
  do L = 2, LA_Global
    ! *** Get local L
    l_local = map2local(L).ll
    ! *** Valid if greater than zero
    if(l_local > 0 )then
      ! *** set local copy of this
      NWVCELLS_local = NWVCELLS_local + 1

      LWVCELL(NWVCELLS_local) = l_local
      LWVMASK(l_local) = LWVMASK_Global(L)
    end if
  end do

  RETURN

9000 STOP ' ERROR READING WAVECELLS.INP.'

END SUBROUTINE READWAVECELLS


END MODULE
