! ----------------------------------------------------------------------
!   This file is a part of EFDC+
!   Website:  https://eemodelingsystem.com/
!   Repository: https://github.com/dsi-llc/EFDC_Plus.git
! ----------------------------------------------------------------------
! Copyright 2021-2022 DSI, LLC
! Distributed under the GNU GPLv2 License.
! ----------------------------------------------------------------------
SUBROUTINE SMRIN1()

  ! CHANGE RECORD
  USE GLOBAL
  USE INFOMOD,ONLY:SKIPCOM

  USE Variables_MPI
  Use Broadcast_Routines
  Use Variables_MPI_Write_Out
  
  IMPLICIT NONE

  INTEGER :: ISSKIP, M, IT, L, LG, I, MM, IN, IJC, J, ISMZX

  REAL    :: TSMTSB, TSMTSE, SMTSDT, SUMNBC, SUMNBD, SUMNBG, SUMPBC, SUMPBD, SUMPBG, SUMCBC, SUMCBD, SUMCBG
  REAL    :: SMTHDD, SMTHDP, SMP1NH4, SMP2NH4, SMTHNH4, SMTHNO3, SMP1H2S, SMP2H2S, SMKD1HS, SMKP1HS, SMTHH2S
  REAL    :: SMKMH2S, SMKCH4, SMTHCH4, XSMK1H2S, SMKSI, SMTHSI, STEMP, TT20

  REAL,SAVE,ALLOCATABLE,DIMENSION(:) :: SMKPOC
  REAL,SAVE,ALLOCATABLE,DIMENSION(:) :: SMKPON
  REAL,SAVE,ALLOCATABLE,DIMENSION(:) :: SMKPOP
  REAL,SAVE,ALLOCATABLE,DIMENSION(:) :: SMTHKC
  REAL,SAVE,ALLOCATABLE,DIMENSION(:) :: SMTHKN
  REAL,SAVE,ALLOCATABLE,DIMENSION(:) :: SMTHKP

  REAL,PARAMETER :: SMCW2=2.739726E-5  ! *** cm/y to m/day

  CHARACTER TITLE(3)*79, CCMRM*1

  IF( .NOT. ALLOCATED(SMKPOC) )THEN
    ALLOCATE(SMKPOC(NSMGM))
    ALLOCATE(SMKPON(NSMGM))
    ALLOCATE(SMKPOP(NSMGM))
    ALLOCATE(SMTHKC(NSMGM))
    ALLOCATE(SMTHKN(NSMGM))
    ALLOCATE(SMTHKP(NSMGM))
    SMKPOC=0.0
    SMKPON=0.0
    SMKPOP=0.0
    SMTHKC=0.0
    SMTHKN=0.0
    SMTHKP=0.0
  ENDIF

  if( process_id == master_id )then
    WRITE(*,'(A)')' WQ: SD READING WQ3DSD.INP - MAIN DIAGENESIS CONTROL FILE'
    OPEN(1,FILE='wq3dsd.inp',STATUS='UNKNOWN')

    OPEN(2,FILE=OUTDIR//'WQ3D.OUT',STATUS='UNKNOWN',POSITION='APPEND')

    ! READ FIRST LINE IN WQ3DSD.INP FILE.  IF FIRST CHARACTER IS '#', THEN
    ! THIS IS THE NEW VERSION WITH ANNOTATED COMMENTS ADDED (I.E., USES THE
    ! SKIPCOMM SUBROUTINE TO SKIP COMMENT LINES.  COMMENT LINES BEGIN WITH
    ! A "C", "C", OR "#" CHARACTER IN COLUMN 1.  IF "#" IS NOT FOUND AS THE
    ! FIRST CHARACTER IN THE FILE, THEN THE OLD METHOD OF READING THE
    ! WQ3DSD.INP FILE IS USED TO PRESERVE BACKWARD COMPATABILITY.
    !
    ISSKIP = 0
    READ(1,'(A1)') CCMRM
    BACKSPACE(1)
    IF( CCMRM  ==  '#') ISSKIP = 1
    CCMRM = '#'

    !01 READ MAIN TITLE CARDS:
    IF( ISSKIP  >  0) CALL SKIPCOM(1,CCMRM,2)
    READ(1,5100) (TITLE(M), M=1,3)
    WRITE(2,999)
    WRITE(2,5100) (TITLE(M), M=1,3)

    !02 I/O CONTROL VARIABLES AND TEMPERATURE RELATED VARIABLES
    WRITE(2,999)
    IF( ISSKIP  >  0) CALL SKIPCOM(1,CCMRM,2)
    READ(1,5100) TITLE(1)
    WRITE(2,5100) TITLE(1)
    IF( ISSKIP  >  0) CALL SKIPCOM(1,CCMRM,2)
    IF( ISSKIP  ==  0) READ(1,999)
    READ(1,*) ISMZ,ISMICI,ISMRST,ISMHYST,ISMZB
    WRITE(2,53)'* # OF ZONES FOR SPAT. VARY. PARAMETERS IN SPM =',ISMZ

    ! *** PMC BEGIN BLOCK
    !      IF( ISMZ > NSMZ) CALL STOPP('ERROR!! ISMZ SHOULD BE <= NSMZ'   PMC
    NSMZ = ISMZ
    IF( ISMICI == 1 )THEN
      WRITE(2,50)'* SPATIALLY/TEMPORALLY-VARYING ICS FROM WQSDICI.INP'
    ELSE IF( ISMICI == 2 )THEN
      WRITE(2,50)'* SPATIALLY/TEMPORALLY-VARYING ICS FROM WQSDRST.INP'
    ELSE
      WRITE(2,50)'* SPATIALLY/TEMPORALLY CONSTANT INITIAL CONDITIONS'
    ENDIF
    IF( ISMRST == 1 )THEN
      WRITE(2,50)'* WRITE SPATIAL DISTRIBUTIONS TO WQSDRST.OUT'
    ELSE
      WRITE(2,50)'* NO WRITING TO ISMORST                           '
    ENDIF
    IF( ISMHYST == 1 )THEN
      WRITE(2,50)'* HYSTERESIS IN BENTHIC MIXING IS ACTIVATED       '
    ELSE
      WRITE(2,50)'* HYSTERESIS IN BENTHIC MIXING IS NOT ACTIVATED   '
    ENDIF

    IF( ISMZB == 1 )THEN
      WRITE(2,50)'* DIAGNOSTIC OUTPUT FOR FUNC ZBRENT (ZBRENT.LOG)  '
      OPEN(99,FILE=OUTDIR//'ZBRENT.LOG',STATUS='UNKNOWN')
      CLOSE(99,STATUS='DELETE')
      OPEN(99,FILE=OUTDIR//'ZBRENT.LOG',STATUS='UNKNOWN')
      WRITE(99,53)'   ITNWQ    L    I    J         SOD          '
      CLOSE(99)
    ELSE
      WRITE(2,50)'* NO DIAGNOSTIC OUTPUT FOR FUNC ZBRENT            '
    ENDIF

    ! *** C03
    IF( ISSKIP  >  0) CALL SKIPCOM(1,CCMRM,2)
    IF( ISSKIP  ==  0) READ(1,999)
    READ(1,*) ISMTS,TSMTSB,TSMTSE,SMTSDT, ISSDBIN

    ISMTS = 0   ! *** EE7.2  REMOVED SEDIMENT FLUX TIME SERIES - EE HAS THIS CAPABILITY
    ISMTSB=0
    TSMTSE=0
    WRITE(2,84) &
      '* TIME-SERIES OUTPUT FROM ', TSMTSB, ' DAY ', &
      '                       TO ', TSMTSE, ' DAY ', &
      '                    EVERY ', SMTSDT, ' HOUR', &
      '                       AT ', ISMTS,  ' LOCATIONS', &
      ' BIN FILE SWITCH ISSDBIN =', ISSDBIN,' (0=OFF)'

    ! *** C04
    IF( ISSKIP  >  0) CALL SKIPCOM(1,CCMRM,2)
    READ(1,50) TITLE(1)
    WRITE(2,999)

    ISMTSB = NINT(TSMTSB/DTD)
    ISMTSE = NINT(TSMTSE/DTD)
    ISMTSDT = NINT(SMTSDT*3600.0/DT)
    WRITE(2,53)': TIME-SERIES STARTING TIME STEP (IN DT UNIT) = ', ISMTSB
    WRITE(2,53)': TIME-SERIES ENDING TIME STEP (IN DT UNIT)   = ', ISMTSE
    WRITE(2,53)': FREQUENCY OF TS OUTPUT  (IN DT UNIT)        = ', ISMTSDT

999 FORMAT(1X)
5100 FORMAT(A79)
5101 FORMAT(10I8)
5103 FORMAT(10F8.4)
5104 FORMAT(I8, 3F8.4)
50  FORMAT(A50)
51  FORMAT(A27, 3(F8.4,2X))
52  FORMAT((A45, E11.4))
53  FORMAT((A48, I10))
55  FORMAT(A31, 2I5)
84  FORMAT(3(A26,F10.4,A5,/), 2(A26,I8,A10,/))

    ! *** C05
    IF( ISSKIP  >  0) CALL SKIPCOM(1,CCMRM,2)
    IF( ISSKIP  ==  0) READ(1,999)
    WRITE(2,999)
    READ(1,5103) SMDIFT
    WRITE(2,52)'* DIFF COEFF (M^2/S) FOR SED TEMPERATURE   = ',SMDIFT
    SMDIFT = SMDIFT*8.64E4   ! *** Convert to m^2/day

    !06 SPATIALLY CONSTANT PARAMETERS FOR SPLITING DEPOSITIONAL FLUXES OF AL
    WRITE(2,999)
    IF( ISSKIP  >  0) CALL SKIPCOM(1,CCMRM,2)
    READ(1,5100) TITLE(1)
    WRITE(2,5100) TITLE(1)

    ! *** C06
    IF( ISSKIP  >  0) CALL SKIPCOM(1,CCMRM,2)
    IF( ISSKIP  ==  0) READ(1,999)
    WRITE(2,999)
    READ(1,*) SMFNBC(1),SMFNBC(2),SMFNBC(3),SMFNBD(1),SMFNBD(2), &
      SMFNBD(3),SMFNBG(1),SMFNBG(2),SMFNBG(3)
    WRITE(2,50)'* CYANOBACTERIA-N SPLIT INTO G1, G2 & G3 CLASSES  '
    WRITE(2,51)' : (FNBC1, FNBC2, FNBC3) = ', (SMFNBC(M),M=1,3)
    WRITE(2,50)'* DIATOMS-N SPLIT INTO G1, G2 & G3 CLASSES        '
    WRITE(2,51)' : (FNBD1, FNBD2, FNBD3) = ', (SMFNBD(M),M=1,3)
    WRITE(2,50)'* BLUE-GREEN ALGAE-N SPLIT INTO G1, G2, G3 CLASSES'
    WRITE(2,51)' : (FNBG1, FNBG2, FNBG3) = ', (SMFNBG(M),M=1,3)
    SUMNBC=SMFNBC(1)+SMFNBC(2)+SMFNBC(3)
    SUMNBD=SMFNBD(1)+SMFNBD(2)+SMFNBD(3)
    SUMNBG=SMFNBG(1)+SMFNBG(2)+SMFNBG(3)
    IF( SUMNBC < 0.9999 .OR. SUMNBC > 1.0001) CALL STOPP('ERROR!! SMFNBC(1)+SMFNBC(2)+SMFNBC(3) SHOULD BE 1')
    IF( SUMNBD < 0.9999 .OR. SUMNBD > 1.0001) CALL STOPP('ERROR!! SMFNBD(1)+SMFNBD(2)+SMFNBD(3) SHOULD BE 1')
    IF( SUMNBG < 0.9999 .OR. SUMNBG > 1.0001) CALL STOPP('ERROR!! SMFNBG(1)+SMFNBG(2)+SMFNBG(3) SHOULD BE 1')

    ! *** C07
    IF( ISSKIP  >  0) CALL SKIPCOM(1,CCMRM,2)
    IF( ISSKIP  ==  0) READ(1,999)
    WRITE(2,999)
    READ(1,*) SMFPBC(1),SMFPBC(2),SMFPBC(3),SMFPBD(1),SMFPBD(2),SMFPBD(3),SMFPBG(1),SMFPBG(2),SMFPBG(3)
    
    WRITE(2,50)'* CYANOBACTERIA-P SPLIT INTO G1, G2 & G3 CLASSES  '
    WRITE(2,51)' : (FPBC1, FPBC2, FPBC3) = ', (SMFPBC(M),M=1,3)
    WRITE(2,50)'* DIATOMS-P SPLIT INTO G1, G2 & G3 CLASSES        '
    WRITE(2,51)' : (FPBD1, FPBD2, FPBD3) = ', (SMFPBD(M),M=1,3)
    WRITE(2,50)'* BLUE-GREEN ALGAE-P SPLIT INTO G1, G2, G3 CLASSES'
    WRITE(2,51)' : (FPBG1, FPBG2, FPBG3) = ', (SMFPBG(M),M=1,3)
    SUMPBC=SMFPBC(1)+SMFPBC(2)+SMFPBC(3)
    SUMPBD=SMFPBD(1)+SMFPBD(2)+SMFPBD(3)
    SUMPBG=SMFPBG(1)+SMFPBG(2)+SMFPBG(3)
    IF( SUMPBC < 0.9999 .OR. SUMPBC > 1.0001) CALL STOPP('ERROR!! SMFPBC(1)+SMFPBC(2)+SMFPBC(3) SHOULD BE 1')
    IF( SUMPBD < 0.9999 .OR. SUMPBD > 1.0001) CALL STOPP('ERROR!! SMFPBD(1)+SMFPBD(2)+SMFPBD(3) SHOULD BE 1')
    IF( SUMPBG < 0.9999 .OR. SUMNBG > 1.0001) CALL STOPP('ERROR!! SMFPBG(1)+SMFPBG(2)+SMFPBG(3) SHOULD BE 1')

    ! *** C08
    IF( ISSKIP  >  0) CALL SKIPCOM(1,CCMRM,2)
    IF( ISSKIP  ==  0) READ(1,999)
    WRITE(2,999)
    READ(1,*) SMFCBC(1),SMFCBC(2),SMFCBC(3),SMFCBD(1),SMFCBD(2),SMFCBD(3),SMFCBG(1),SMFCBG(2),SMFCBG(3)

    WRITE(2,50)'* CYANOBACTERIA-C SPLIT INTO G1, G2 & G3 CLASSES  '
    WRITE(2,51)' : (FCBC1, FCBC2, FCBC3) = ', (SMFCBC(M),M=1,3)
    WRITE(2,50)'* DIATOMS-C SPLIT INTO G1, G2 & G3 CLASSES        '
    WRITE(2,51)' : (FCBD1, FCBD2, FCBD3) = ', (SMFCBD(M),M=1,3)
    WRITE(2,50)'* BLUE-GREEN ALGAE-C SPLIT INTO G1, G2, G3 CLASSES'
    WRITE(2,51)' : (FCBG1, FCBG2, FCBG3) = ', (SMFCBG(M),M=1,3)
    SUMCBC=SMFCBC(1)+SMFCBC(2)+SMFCBC(3)
    SUMCBD=SMFCBD(1)+SMFCBD(2)+SMFCBD(3)
    SUMCBG=SMFCBG(1)+SMFCBG(2)+SMFCBG(3)
    IF( SUMCBC < 0.9999 .OR. SUMCBC > 1.0001) CALL STOPP('ERROR!! SMFCBC(1)+SMFCBC(2)+SMFCBC(3) SHOULD BE 1')
    IF( SUMCBD < 0.9999 .OR. SUMCBD > 1.0001) CALL STOPP('ERROR!! SMFPBD(1)+SMFCBD(2)+SMFCBD(3) SHOULD BE 1')
    IF( SUMCBG < 0.9999 .OR. SUMCBG > 1.0001) CALL STOPP('ERROR!! SMFCBG(1)+SMFCBG(2)+SMFCBG(3) SHOULD BE 1')

    ! *** C09 SPATIALLY CONSTANT PARAMETERS FOR DIAGENESIS
    WRITE(2,999)
    IF( ISSKIP  >  0) CALL SKIPCOM(1,CCMRM,2)
    READ(1,5100) TITLE(1)
    WRITE(2,5100) TITLE(1)
    IF( ISSKIP  >  0) CALL SKIPCOM(1,CCMRM,2)
    IF( ISSKIP  ==  0) READ(1,999)
    READ(1,*) SMKPON(1),SMKPON(2),SMKPON(3),SMKPOP(1),SMKPOP(2),SMKPOP(3),SMKPOC(1),SMKPOC(2),SMKPOC(3)
    WRITE(2,50)'* DIAGENESIS RATE AT 20OC IN LAYER 2 (/DAY)       '
    WRITE(2,51)' : (KPON1,KPON2,KPON3)   = ', (SMKPON(M),M=1,3)
    WRITE(2,51)' : (KPOP1,KPOP2,KPOP3)   = ', (SMKPOP(M),M=1,3)
    WRITE(2,51)' : (KPOC1,KPOC2,KPOC3)   = ', (SMKPOC(M),M=1,3)

    ! *** C10
    IF( ISSKIP  >  0) CALL SKIPCOM(1,CCMRM,2)
    IF( ISSKIP  ==  0) READ(1,999)
    READ(1,*) SMTHKN(1),SMTHKN(2),SMTHKN(3),SMTHKP(1),SMTHKP(2),SMTHKP(3),SMTHKC(1),SMTHKC(2),SMTHKC(3)
    
    WRITE(2,50)'* TEMPERATURE EFFECT ON DIAGENESIS RATE           '
    WRITE(2,51)' : (THKN1,THKN2,THKN3)   = ', (SMTHKN(M),M=1,3)
    WRITE(2,51)' : (THKP1,THKP2,THKP3)   = ', (SMTHKP(M),M=1,3)
    WRITE(2,51)' : (THKC1,THKC2,THKC3)   = ', (SMTHKC(M),M=1,3)
    WRITE(2,999)

    ! *** C11
    IF( ISSKIP  >  0) CALL SKIPCOM(1,CCMRM,2)
    READ(1,5100) TITLE(1)
    WRITE(2,5100) TITLE(1)
    IF( ISSKIP  >  0) CALL SKIPCOM(1,CCMRM,2)
    IF( ISSKIP  ==  0) READ(1,999)
    READ(1,*) SMM1,SMM2,SMTHDD,SMTHDP,SMPOCR,SMKMDP,SMKBST,XSMDPMIN,SMRBIBT

    ! *** C12
    IF( ISSKIP  >  0) CALL SKIPCOM(1,CCMRM,2)
    IF( ISSKIP  ==  0) READ(1,999)
    READ(1,*) SMO2BS,SMHYLAG,SMHYDUR
    WRITE(2,50)'* SOLID CONCENTRATIONS (KG/L) IN LAYERS 1 AND 2   '
    WRITE(2,51)' : (RM1, RM2)            = ', SMM1,SMM2
    WRITE(2,50)'* TEMP EFFECT ON MIXING IN DISSOLVED & PARTICULATE'
    WRITE(2,51)' : (THDD, THDP)          = ', SMTHDD,SMTHDP
    WRITE(2,52)'* HALF-SAT. CONST OF O2 FOR PARTICLE MIXING= ',SMKMDP &
      ,': FIRST-ORDER DECAY RATE FOR STRESS (/DAY) = ',SMKBST &
      ,'* RATIO OF BIO-IRRIGATION TO BIOTURBATION  = ',SMRBIBT &
      ,'* REFERENCE CONC (GC/M^3) FOR GPOC(1)      = ',SMPOCR &
      ,'* MINIMUM DIFFUSION COEFF (M^2/DAY)        = ',XSMDPMIN &
      ,'* CRITICAL O2 (G/M^3) FOR BENTH. HYSTERESIS= ',SMO2BS &
      ,': TIME LAG (DAYS) FOR MAX STRESS TO BE KEPT= ',SMHYLAG &
      ,': TIME DURATION (D) ABOVE WHICH HYSTERESIS = ',SMHYDUR
    !ISMTDMBS = NINT(SMHYLAG/DTWQ)  wq variable dt
    !ISMTCMBS = NINT(SMHYDUR/DTWQ)  wq variable dt
    SM1OKMDP = 1.0/SMKMDP
    WRITE(2,999)
    
    ! *** C13
    IF( ISSKIP  >  0) CALL SKIPCOM(1,CCMRM,2)
    READ(1,5100) TITLE(1)
    WRITE(2,5100) TITLE(1)
    IF( ISSKIP  >  0) CALL SKIPCOM(1,CCMRM,2)
    IF( ISSKIP  ==  0) READ(1,999)
    READ(1,*) SMP1NH4,SMP2NH4,SMKMNH4,SMKMO2N,SMTHNH4,SMTHNO3,SMP2PO4,SMCO2PO4
    WRITE(2,50)'* PARTITION COEFF BET/ DISSOLVED AND SORBED NH4   '
    WRITE(2,51)' : (P1NH4, P2NH4)        = ', SMP1NH4,SMP2NH4
    WRITE(2,50)'* HALF-SAT. CONST FOR NITRI. (GN/M^3, GO2/M^3)    '
    WRITE(2,51)' : (KMNH4, KMNH4O2)      = ', SMKMNH4,SMKMO2N
    WRITE(2,50)'* TEMP EFFECT ON KNH4 & KNO3                      '
    WRITE(2,51)' : (THNH4, THNO3)        = ', SMTHNH4,SMTHNO3
    WRITE(2,52)'* ANAEROBIC (LAY1) PARTITION COEF FOR PO4 (L/KG) = ', SMP2PO4 &
              ,': CRITICAL DO (MG/L) FOR PO4 SORPTION            = ', SMCO2PO4
    SMFD1NH4 = 1.0 / (1.0 + SMM1*SMP1NH4)
    SMFP1NH4 = 1.0 - SMFD1NH4
    SMFD2NH4 = 1.0 / (1.0 + SMM2*SMP2NH4)
    SMFP2NH4 = 1.0 - SMFD2NH4
    SMKMO2N = SMKMO2N * 2.0
    SMFD2PO4 = 1.0 / (1.0 + SMM2*SMP2PO4)
    SMFP2PO4 = 1.0 - SMFD2PO4
    WRITE(2,999)

    ! *** C14
    IF( ISSKIP  >  0) CALL SKIPCOM(1,CCMRM,2)
    READ(1,5100) TITLE(1)
    WRITE(2,5100) TITLE(1)
    IF( ISSKIP  >  0) CALL SKIPCOM(1,CCMRM,2)
    IF( ISSKIP  ==  0) READ(1,999)
    READ(1,*) SMP1H2S,SMP2H2S,SMKD1HS,SMKP1HS,SMTHH2S,SMKMH2S,SMKCH4,SMTHCH4,SMCSHSCH
    WRITE(2,50)'* PARTITION COEFF FOR H2S IN LAYER 1 (L/KG)       '
    WRITE(2,51)' : (P1H2S, P2H2S)        = ', SMP1H2S,SMP2H2S
    WRITE(2,50)'* REACTION VEL (M/D) FOR DISSOL & PART. IN LAYER 1'
    WRITE(2,51)' : (KH2SD1, KH2SP1)      = ', SMKD1HS,SMKP1HS
    WRITE(2,52)'* CRITICAL SAL (PPT) FOR H2S/CH4 OXIDATION = ', SMCSHSCH
    WRITE(2,52)'* TEMPERATURE EFFECT ON H2S OXIDATION RATE = ', SMTHH2S &
              ,': OXYGEN EFFECT (MG/L) ON H2S OXIDATION    = ',SMKMH2S
    WRITE(2,52)'* METHANE OXIDATION REACTION VELOCITY (M/D)= ',SMKCH4 &
              ,': TEMPERATURE EFFECT ON CH4 OXIDATION RATE = ',SMTHCH4
    SMFD1H2S = 1.0 / (1.0 + SMM1*SMP1H2S)
    SMFP1H2S = 1.0 - SMFD1H2S
    SMFD2H2S = 1.0 / (1.0 + SMM2*SMP2H2S)
    SMFP2H2S = 1.0 - SMFD2H2S
    XSMK1H2S = (SMKD1HS*SMKD1HS*SMFD1H2S + SMKP1HS*SMKP1HS*SMFP1H2S) / (2.0*SMKMH2S)

    ! *** C15
    IF( ISSKIP  >  0) CALL SKIPCOM(1,CCMRM,2)
    IF( ISSKIP  ==  0) READ(1,999)
    READ(1,*) SMO2C,SMO2NO3,SMO2NH4
    WRITE(2,52)'* STOICHI COEF FOR C USED BY H2S OX (GO2/GC)=',SMO2C &
              ,': STOICHI COEF FOR C USED BY DENITR (GO2/GN)=',SMO2NO3 &
              ,': STOICHI COEF FOR O2 USED BY NITRI (GO2/GN)=',SMO2NH4
    WRITE(2,999)

    ! *** C16
    IF( ISSKIP  >  0) CALL SKIPCOM(1,CCMRM,2)
    READ(1,5100) TITLE(1)
    WRITE(2,5100) TITLE(1)
    IF( ISSKIP  >  0) CALL SKIPCOM(1,CCMRM,2)
    IF( ISSKIP  ==  0) READ(1,999)
    READ(1,*) SMKSI,SMTHSI,SMKMPSI,SMSISAT,SMP2SI,SMDP1SI,SMCO2SI,SMJDSI
    WRITE(2,52)'* PSI DISSOL. RATE AT 20C IN LAYER 2 (/D)  = ',SMKSI &
      ,': TEMPERATURE EFFECT ON PSI DISSOLUTION    = ',SMTHSI &
      ,': SAT. CONC. IN PORE WATER (G SI/M^3)      = ',SMSISAT &
      ,'* PARTITION COEF FOR SI IN LAYER 2 (L/KG)  = ',SMP2SI &
      ,': INCREMENTAL IN PART. COEF IN LAYER1, P1SI= ',SMDP1SI &
      ,': CRITICAL DO (MG/L) FOR SI SORPTION       = ',SMCO2SI &
      ,'* DETRITAL FLUX (G/M^2/D) EXCEPT DIATOMS   = ',SMJDSI &
      ,'* DISSOLUTION HALF-SAT CONSTANT (G SI/M^3) = ',SMKMPSI
    SMFD2SI = 1.0 / (1.0 + SMM2*SMP2SI)
    SMFP2SI = 1.0 - SMFD2SI

    ! *** SET UP LOOK-UP TABLE FOR TEMPERATURE DEPENDENCY OVER -1OC TO 50OC
    WQTDsMIN=-10
    WQTDsMAX=+50
    STEMP=WQTDsMIN
    WQTDsINC=(WQTDsMAX-WQTDsMIN)/NWQTD
    DO IT=1,NWQTD
      !STEMP = REAL(IT-1)*0.1 - 4.95
      TT20 = STEMP-20.0
      DO M=1,3
        SMTDND(IT,M) = SMKPON(M) * SMTHKN(M)**TT20
        SMTDPD(IT,M) = SMKPOP(M) * SMTHKP(M)**TT20
        SMTDCD(IT,M) = SMKPOC(M) * SMTHKC(M)**TT20
      ENDDO
      SMTDDP(IT) = SMTHDP**TT20
      SMTDDD(IT) = SMTHDD**TT20
      SMTDNH4(IT) = SMTHNH4**TT20
      SMTDNO3(IT) = SMTHNO3**TT20
      SMK1H2S(IT)= XSMK1H2S * SMTHH2S**TT20
      SMTD1CH4(IT) = 0.97656**TT20 * 20.0
      SMTD2CH4(IT) = SMKCH4 * SMTHCH4**TT20
      SMTDSI(IT) = SMKSI * SMTHSI**TT20

      STEMP=STEMP + WQTDsINC
    ENDDO

    ! *** C17
    WRITE(2,998)
    IF( ISSKIP  >  0) CALL SKIPCOM(1,CCMRM,2)
    READ(1,5100) TITLE(1)
    WRITE(2,5100) TITLE(1)
    IF( ISSKIP  >  0) CALL SKIPCOM(1,CCMRM,2)
    READ(1,5100) TITLE(1)
    WRITE(2,5100) TITLE(1)
    READ(1,*) SMPON(1,1),SMPON(1,2),SMPON(1,3),SMPOP(1,1), &
      SMPOP(1,2),SMPOP(1,3),SMPOC(1,1),SMPOC(1,2),SMPOC(1,3)
    IF( ISMICI /= 1 .AND. ISMICI /= 2) &
      WRITE(2,5105) SMPON(1,1),SMPON(1,2),SMPON(1,3),SMPOP(1,1), &
      SMPOP(1,2),SMPOP(1,3),SMPOC(1,1),SMPOC(1,2),SMPOC(1,3)

    ! *** C18
    IF( ISSKIP  >  0) CALL SKIPCOM(1,CCMRM,2)
    READ(1,5100) TITLE(1)
    WRITE(2,5100) TITLE(1)
    READ(1,*) SM1NH4(1), SM2NH4(1), SM2NO3(1), SM2PO4(1), SM2H2S(1), SMPSI(1), SM2SI(1), SMBST(1), SMT(1)
    IF( ISMICI /= 1 .AND. ISMICI /= 2 )THEN
      WRITE(2,5105) SM1NH4(1), SM2NH4(1), SM2NO3(1), SM2PO4(1), SM2H2S(1), SMPSI(1), SM2SI(1), SMBST(1), SMT(1)
    endif
    !  DO L=2,LA
    !    DO M=1,NSMG
    !      SMPON(L,M)=SMPON(1,M)
    !      SMPOP(L,M)=SMPOP(1,M)
    !      SMPOC(L,M)=SMPOC(1,M)
    !    ENDDO
    !    SM1NH4(L)=SM1NH4(1)
    !    SM2NH4(L)=SM2NH4(1)
    !    SM2NO3(L)=SM2NO3(1)
    !    SM2PO4(L)=SM2PO4(1)
    !    SM2H2S(L)=SM2H2S(1)
    !    SMPSI(L) =SMPSI(1)
    !    SM2SI(L) =SM2SI(1)
    !    SMBST(L) =SMBST(1)
    !    SMT(L)   =SMT(1)
    !  ENDDO
    !ENDIF

    ! *** C19   SMDIFT IN M^2/D
    WRITE(2,998)
    IF( ISSKIP  >  0) CALL SKIPCOM(1,CCMRM,2)
    READ(1,5100) TITLE(1)
    WRITE(2,5100) TITLE(1)
    IF( ISSKIP  >  0) CALL SKIPCOM(1,CCMRM,2)
    READ(1,5100) TITLE(1)
    WRITE(2,5100) TITLE(1)
    DO I=1,ISMZ
      READ(1,*)   MM,SMHSED(I),SMW2(I),SMDD(I),SMDP(I),SMKNH4(I),SMK1NO3(I),SMK2NO3(I),SMDP1PO4(I), SODMULT(I)
      WRITE(2,56) MM,SMHSED(I),SMW2(I),SMDD(I),SMDP(I),SMKNH4(I),SMK1NO3(I),SMK2NO3(I),SMDP1PO4(I), SODMULT(I)
      SMW2(I) = SMW2(I)*SMCW2        ! *** M/Day
      SMDTOH(I) = DTWQ/SMHSED(I)
      SMHODT(I) = SMHSED(I)/DTWQ     ! *** Fixed DELT only
      SMDP(I) = SMDP(I) / (SMHSED(I)*SMPOCR+ 1.E-18)
      SMDD(I) = SMDD(I) / (SMHSED(I)+ 1.E-18)
      SMKNH4(I) = SMKNH4(I)*SMKNH4(I) * SMKMNH4
      SMK1NO3(I) = SMK1NO3(I)*SMK1NO3(I)
      SM1DIFT(I) = SMDIFT * SMDTOH(I)/(SMHSED(I)+ 1.E-18)
      SM2DIFT(I) = 1.0 / (1.0 + SM1DIFT(I))
      SMW2DTOH(I) = 1.0 + SMW2(I)*SMDTOH(I)
      SMW2PHODT(I) = SMW2(I) + SMHODT(I)
      SMDPMIN(I) = XSMDPMIN / (SMHSED(I)+ 1.E-18)
    ENDDO
    WRITE(2,998)

    ! *** C20
    IF( ISSKIP  >  0) CALL SKIPCOM(1,CCMRM,2)
    READ(1,5100) TITLE(1)
    WRITE(2,5100) TITLE(1)
    IF( ISSKIP  >  0) CALL SKIPCOM(1,CCMRM,2)
    READ(1,5100) TITLE(1)
    WRITE(2,5100) TITLE(1)
    DO I=1,ISMZ
      READ(1,*)   MM,SMFNR(I,1),SMFNR(I,2),SMFNR(I,3),SMFPR(I,1),SMFPR(I,2),SMFPR(I,3),SMFCR(I,1),SMFCR(I,2),SMFCR(I,3)
      WRITE(2,54) MM,SMFNR(I,1),SMFNR(I,2),SMFNR(I,3),SMFPR(I,1),SMFPR(I,2),SMFPR(I,3),SMFCR(I,1),SMFCR(I,2),SMFCR(I,3)
      SUMNBC=SMFNR(I,1)+SMFNR(I,2)+SMFNR(I,3)
      SUMNBD=SMFPR(I,1)+SMFPR(I,2)+SMFPR(I,3)
      SUMNBG=SMFCR(I,1)+SMFCR(I,2)+SMFCR(I,3)
      IF( SUMNBC < 0.9999 .OR. SUMNBC > 1.0001) &
        CALL STOPP('ERROR!! SMFNR(I,1)+SMFNR(I,2)+SMFNR(I,3) SHOULD BE 1')
      IF( SUMNBD < 0.9999 .OR. SUMNBD > 1.0001) &
        CALL STOPP('ERROR!! SMFPR(I,1)+SMFPR(I,2)+SMFPR(I,3) SHOULD BE 1')
      IF( SUMNBG < 0.9999 .OR. SUMNBG > 1.0001) &
        CALL STOPP('ERROR!! SMFCR(I,1)+SMFCR(I,2)+SMFCR(I,3) SHOULD BE 1')
    ENDDO
    CLOSE(1)
    
6666 FORMAT(A30)
 998 FORMAT(80X)
5105 FORMAT(10F8.2)
  54 FORMAT(I8, 10F8.3)
  56 FORMAT(I8, 3F8.3, E8.1, 6F8.3)

  endif     ! *** End of master_id

  ! *** Scalar Variables
  Call Broadcast_Scalar(ISMZ,     master_id)
  Call Broadcast_Scalar(NSMZ,     master_id)
  Call Broadcast_Scalar(ISMICI,   master_id)
  Call Broadcast_Scalar(ISMRST,   master_id)
  Call Broadcast_Scalar(ISMHYST,  master_id)
  Call Broadcast_Scalar(ISMZB,    master_id)

  Call Broadcast_Scalar(ISMTS,    master_id)
  Call Broadcast_Scalar(ISMTSB,   master_id)
  Call Broadcast_Scalar(TSMTSB,   master_id)
  Call Broadcast_Scalar(ISMTSE,   master_id)
  Call Broadcast_Scalar(TSMTSE,   master_id)
  Call Broadcast_Scalar(ISMTSDT,  master_id)
  Call Broadcast_Scalar(SMTSDT,   master_id)
  Call Broadcast_Scalar(ISSDBIN,  master_id)

  Call Broadcast_Scalar(SMDIFT,   master_id)

  Call Broadcast_Scalar(SMM1,     master_id)
  Call Broadcast_Scalar(SMM2,     master_id)
  Call Broadcast_Scalar(SMTHDD,   master_id)
  Call Broadcast_Scalar(SMTHDP,   master_id)
  Call Broadcast_Scalar(SMPOCR,   master_id)
  Call Broadcast_Scalar(SMKMDP,   master_id)
  Call Broadcast_Scalar(SMKBST,   master_id)
  Call Broadcast_Scalar(XSMDPMIN, master_id)
  Call Broadcast_Scalar(SMRBIBT,  master_id)

  Call Broadcast_Scalar(SMO2BS,   master_id)
  Call Broadcast_Scalar(SMHYLAG,  master_id)
  Call Broadcast_Scalar(SMHYDUR,  master_id)
  Call Broadcast_Scalar(SM1OKMDP, master_id)

  Call Broadcast_Scalar(SMP1NH4,  master_id)
  Call Broadcast_Scalar(SMP2NH4,  master_id)
  Call Broadcast_Scalar(SMKMNH4,  master_id)
  Call Broadcast_Scalar(SMKMO2N,  master_id)
  Call Broadcast_Scalar(SMTHNH4,  master_id)
  Call Broadcast_Scalar(SMTHNO3,  master_id)
  Call Broadcast_Scalar(SMP2PO4,  master_id)
  Call Broadcast_Scalar(SMCO2PO4, master_id)

  Call Broadcast_Scalar(SMFD1NH4, master_id)
  Call Broadcast_Scalar(SMFP1NH4, master_id)
  Call Broadcast_Scalar(SMFD2NH4, master_id)
  Call Broadcast_Scalar(SMFP2NH4, master_id)
  Call Broadcast_Scalar(SMKMO2N,  master_id)
  Call Broadcast_Scalar(SMFD2PO4, master_id)
  Call Broadcast_Scalar(SMFP2PO4, master_id)

  Call Broadcast_Scalar(SMP1H2S,  master_id)
  Call Broadcast_Scalar(SMP2H2S,  master_id)
  Call Broadcast_Scalar(SMKD1HS,  master_id)
  Call Broadcast_Scalar(SMKP1HS,  master_id)
  Call Broadcast_Scalar(SMTHH2S,  master_id)
  Call Broadcast_Scalar(SMKMH2S,  master_id)
  Call Broadcast_Scalar(SMKCH4,   master_id)
  Call Broadcast_Scalar(SMTHCH4,  master_id)
  Call Broadcast_Scalar(SMCSHSCH, master_id)

  Call Broadcast_Scalar(SMFD1H2S, master_id)
  Call Broadcast_Scalar(SMFP1H2S, master_id)
  Call Broadcast_Scalar(SMFD2H2S, master_id)
  Call Broadcast_Scalar(SMFP2H2S, master_id)
  Call Broadcast_Scalar(XSMK1H2S, master_id)

  Call Broadcast_Scalar(SMO2C,    master_id)
  Call Broadcast_Scalar(SMO2NO3,  master_id)
  Call Broadcast_Scalar(SMO2NH4,  master_id)

  Call Broadcast_Scalar(SMKSI,    master_id)
  Call Broadcast_Scalar(SMTHSI,   master_id)
  Call Broadcast_Scalar(SMKMPSI,  master_id)
  Call Broadcast_Scalar(SMSISAT,  master_id)
  Call Broadcast_Scalar(SMP2SI,   master_id)
  Call Broadcast_Scalar(SMDP1SI,  master_id)
  Call Broadcast_Scalar(SMCO2SI,  master_id)
  Call Broadcast_Scalar(SMJDSI,   master_id)

  Call Broadcast_Scalar(SMFD2SI,  master_id)
  Call Broadcast_Scalar(SMFP2SI,  master_id)

  Call Broadcast_Scalar(WQTDsMIN, master_id)
  Call Broadcast_Scalar(WQTDsMAX, master_id)
  Call Broadcast_Scalar(STEMP,    master_id)
  Call Broadcast_Scalar(WQTDsINC, master_id)

  ! *** Array Variables
  Call Broadcast_Array(SMFNBC,    master_id)
  Call Broadcast_Array(SMFNBD,    master_id)
  Call Broadcast_Array(SMFNBG,    master_id)

  Call Broadcast_Array(SMFPBC,    master_id)
  Call Broadcast_Array(SMFPBD,    master_id)
  Call Broadcast_Array(SMFPBG,    master_id)

  Call Broadcast_Array(SMFCBC,    master_id)
  Call Broadcast_Array(SMFCBD,    master_id)
  Call Broadcast_Array(SMFCBG,    master_id)

  Call Broadcast_Array(SMKPON,    master_id)
  Call Broadcast_Array(SMKPOP,    master_id)
  Call Broadcast_Array(SMKPOC,    master_id)

  Call Broadcast_Array(SMTHKN,    master_id)
  Call Broadcast_Array(SMTHKP,    master_id)
  Call Broadcast_Array(SMTHKC,    master_id)

  Call Broadcast_Array(SMTDND,    master_id)
  Call Broadcast_Array(SMTDPD,    master_id)
  Call Broadcast_Array(SMTDCD,    master_id)

  Call Broadcast_Array(SMTDDP,    master_id)
  Call Broadcast_Array(SMTDDD,    master_id)
  Call Broadcast_Array(SMTDNH4,   master_id)
  Call Broadcast_Array(SMTDNO3,   master_id)
  Call Broadcast_Array(SMK1H2S,   master_id)
  Call Broadcast_Array(SMTD1CH4,  master_id)
  Call Broadcast_Array(SMTD2CH4,  master_id)
  Call Broadcast_Array(SMTDSI,    master_id)

  Call Broadcast_Array(SMPON,     master_id)
  Call Broadcast_Array(SMPOP,     master_id)
  Call Broadcast_Array(SMPOC,     master_id)

  Call Broadcast_Array(SM1NH4,    master_id)
  Call Broadcast_Array(SM2NH4,    master_id)
  Call Broadcast_Array(SM2NO3,    master_id)
  Call Broadcast_Array(SM2PO4,    master_id)
  Call Broadcast_Array(SM2H2S,    master_id)
  Call Broadcast_Array(SMPSI,     master_id)
  Call Broadcast_Array(SM2SI,     master_id)
  Call Broadcast_Array(SMBST,     master_id)
  Call Broadcast_Array(SMT,       master_id)

  Call Broadcast_Array(SMHSED,    master_id)
  Call Broadcast_Array(SMW2,      master_id)
  Call Broadcast_Array(SMDD,      master_id)
  Call Broadcast_Array(SMDP,      master_id)
  Call Broadcast_Array(SMKNH4,    master_id)
  Call Broadcast_Array(SMK1NO3,   master_id)
  Call Broadcast_Array(SMK2NO3,   master_id)
  Call Broadcast_Array(SMDP1PO4,  master_id)
  Call Broadcast_Array(SODMULT,   master_id)

  Call Broadcast_Array(SMW2,      master_id)
  Call Broadcast_Array(SMDTOH,    master_id)
  Call Broadcast_Array(SMHODT,    master_id)
  Call Broadcast_Array(SMDP,      master_id)
  Call Broadcast_Array(SMDD,      master_id)
  Call Broadcast_Array(SMKNH4,    master_id)
  Call Broadcast_Array(SMK1NO3,   master_id)
  Call Broadcast_Array(SM1DIFT,   master_id)
  Call Broadcast_Array(SM2DIFT,   master_id)
  Call Broadcast_Array(SMW2DTOH,  master_id)
  Call Broadcast_Array(SMW2PHODT, master_id)
  Call Broadcast_Array(SMDPMIN,   master_id)

  Call Broadcast_Array(SMFNR,     master_id)
  Call Broadcast_Array(SMFPR,     master_id)
  Call Broadcast_Array(SMFCR,     master_id)
  Call Broadcast_Array(ISMZMAP,   master_id)

  ! *** Spatially Variable Handling
  IF( ISMICI /= 1 .AND. ISMICI /= 2 )THEN
      
    DO L=2,LA
      DO M=1,NSMG
        SMPON(L,M) = SMPON(1,M)
        SMPOP(L,M) = SMPOP(1,M)
        SMPOC(L,M) = SMPOC(1,M)
      ENDDO
      SM1NH4(L) = SM1NH4(1)
      SM2NH4(L) = SM2NH4(1)
      SM2NO3(L) = SM2NO3(1)
      SM2PO4(L) = SM2PO4(1)
      SM2H2S(L) = SM2H2S(1)
      SMPSI(L)  = SMPSI(1)
      SM2SI(L)  = SM2SI(1)
      SMBST(L)  = SMBST(1)
      SMT(L)    = SMT(1)
    ENDDO
  ENDIF

  ! *** Bed diagensis map
  DO L=2,LA
    ISMZMAP(L) = 1
  ENDDO

  ! *** READ IN MAPPING INFOR. FOR SPATIALLY-VARYING SED PARAMETERS (UNIT #7).
  IF( ISMZ  >  1 )THEN
    Allocate(I1D_Global(LCM_Global))
    I1D_Global = 0

    if( process_id == master_id )then
      WRITE(*,'(A)')' WQ: SD READING WQSDMAP.INP'
      OPEN(1,FILE='wqsdmap.inp',STATUS='UNKNOWN')

      WRITE(2,999)
      CALL SKIPCOM(1,'*',2)  ! *** SKIP OVER TITLE AND AND HEADER LINES

      WRITE(2,92)
      IN=0
      
      IJC = IC_Global*JC_Global

      DO M=1,IJC
        READ(1,*,END=1111) I, J, ISMZX
        IN = IN + 1

        IF( IJCT_Global(I,J) < 1 .OR. IJCT_Global(I,J) > 8 .OR. ISMZX > ISMZ )THEN
          PRINT*, 'I, J, IJCT(I,J) = ', I,J,IJCT_Global(I,J)
          CALL STOPP('ERROR!! INVALID (I,J) IN FILE WQSDMAP.INP')
        ENDIF

        LG = LIJ_Global(I,J)
        I1D_Global(LG) = ISMZX                 ! *** ISMZMAP
        WRITE(2,91) LG, I, J, I1D_Global(LG)
      ENDDO
1111  CONTINUE

      IF( IN /= (LA_Global-1) )THEN  
        PRINT *, 'ALL ACTIVE SED. CELLS SHOULD BE MAPPED FOR SED PAR.'
        CALL STOPP('ERROR!! NUMBER OF LINES IN FILE WQSDMAP.INP =\ (LA-1)')
      ENDIF
      CLOSE(1)
      CLOSE(2)
    endif
  
    Call Broadcast_Array(I1D_Global, master_id)
    
    ! *** Map to Local Domain
    DO LG=2,LA_GLOBAL
      L = Map2Local(LG).LL
      IF( L > 1 )THEN
        ISMZMAP(L) = I1D_Global(LG)
      ENDIF
    ENDDO
    DEALLOCATE(I1D_Global)   
    
  ENDIF
  
90 FORMAT(A79)
91 FORMAT(15I5)
92 FORMAT('    L    I    J    ISMZMAP')

  RETURN

END
