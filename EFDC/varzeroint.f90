! ----------------------------------------------------------------------
!   This file is a part of EFDC+
!   Website:  https://eemodelingsystem.com/
!   Repository: https://github.com/dsi-llc/EFDC_Plus.git
! ----------------------------------------------------------------------
! Copyright 2021-2022 DSI, LLC
! Distributed under the GNU GPLv2 License.
! ----------------------------------------------------------------------
SUBROUTINE VARZEROInt

  ! *** THIS SUBROUTINE ZERO'S ALL OF THE ARRAYS AFTER ALLOCATION

  !----------------------------------------------------------------------!  
  ! CHANGE RECORD  
  ! DATE MODIFIED     BY               DESCRIPTION
  !----------------------------------------------------------------------!
  !    2015-06       PAUL M. CRAIG     IMPLEMENTED SIGMA-Z (SGZ) IN EE7.3 

  USE GLOBAL  
  Use Variables_MPI
  
  if( process_id == master_id )THEN
    WRITE(*,'(A)')'INITIALIZING INTEGER ARRAYS' 
  end if

 !ISADAC = 0
  ! *** INTEGER ARRAYS
  GRPID = 0
  IACTLR = 0
  IAIJ = 0
  IAKL = 0
  IAP = 0
  ICALJP = 0
  ICBE = 0
  ICBN = 0
  ICBS = 0
  ICBW = 0
  ICCDA = 0
  ICDA = 0
  ICFLMP = 0
  ICSMTS = 0
  IGWSER = 0
  IJCT = 0
  IJCTLT = 0
  IL = 0
  ILLSHA = 0
  ILLT = 0
  ILTMSR = 0
  !IMASKDRY = 0
  IMDCHH = 0
  IMDCHU = 0
  IMDCHV = 0
  INPNS = 0
  INTPSER = 0
  IOUTJP = 0
  IPART = 0
  IPBE = 0
  IPBN = 0
  IPBS = 0
  IPBW = 0
  IQJP = 0
  IQS = 0
  ISCDRY = 0
  ISDJP = 0
  ISENT = 0
  ISPBE = 0
  ISPBN = 0
  ISPBS = 0
  ISPBW = 0
  ISPNS = 0
  ISSBCP = 0
  ISTJP = 0
  ISUDPC = 0
  ITPCDA = 0
  IUPCJP = 0
  IWGG = 0
  JCBE = 0
  JCBN = 0
  JCBS = 0
  JCBW = 0
  JCCDA = 0
  JCDA = 0
  JL = 0
  JLLSHA = 0
  JLLT = 0
  JLTMSR = 0
  JMDCHH = 0
  JMDCHU = 0
  JMDCHV = 0
  JNPNS = 0
  JPBE = 0
  JPBN = 0
  JPBS = 0
  JPBW = 0
  JQCAX = 0
  JQCTLD = 0
  JQCTLU = 0
  JQJP = 0
  JQS = 0
  JSPNS = 0
  JUPCJP = 0
  JWGG = 0
  KBT = 0
  KCEFDC = 0
  KEFFJP = 0
  KFEFDC = 0
  KPS = 0
  KQJP = 0
  KUPCJP = 0
  KUPW = 0
  LBERC = 0
  LBNRC = 0
  LBSRC = 0
  LBWRC = 0
  LCBE = 0
  LCBN = 0
  LCBS = 0
  LCBW = 0
  LCDA = 0
  LCONSOL = 0
  LCT = 0
  LCTLT = 0
  LIJ = 0
  LIJLT = 0
  LJUNX = 0
  LJUNY = 0
  LLBC = 0
  LLRC = 0
  LLSHA = 0
  LMDCHH = 0
  LMDCHU = 0
  LMDCHV = 0
  LNC = 0
  LNCLT = 0
  LNEC = 0
  LNWC = 0
  LOBCS = 0
  LOBCS2 = 0
  LBCS = 0
  LORDER = 0
  LPBE = 0
  LPBN = 0
  LPBS = 0
  LPBW = 0
  LQS = 0
  LQWRD = 0
  LQWRU = 0
  LSBLBCD = 0
  LSBLBCU = 0
  LSC = 0
  LSCLT = 0
  LSEC = 0
  LSHAB = 0
  LSHAP = 0
  LSHAU = 0
  LSHAUE = 0
  LSMTS = 0
  LSWC = 0
  LUPU = 0
  LUPV = 0
  LWGG = 0
  LWVCELL = 0
  MCNTLR = 0
  MCSER = 0
  MTSCLAST = 0
  MFDCHZ = 0
  MDCHTYP = 0
  MGWSER = 0
  MTSGWLAST = 0
  MPSER = 0
  MTSPLAST = 0
  MQCTL = 0
  MQSER = 0
  MTSQLAST = 0
  MQWRSR = 0
  MTSWRLAST = 0
  MTMSRA = 0
  MTMSRC = 0
  MTMSRP = 0
  MTMSRQ = 0
  MTMSRQE = 0
  MTMSRU = 0
  MTMSRUE = 0
  MTMSRUT = 0
  MTSCUR = 0
  MTSSTSP = 0
  MVEGL = 0
  MVEGSER = 0
  MVEGTLAST = 0
  NATDRY = 0
  NCSER = 0
  NCSERA = 0
  NCSERE = 0
  NCSERJP = 0
  NCSERN = 0
  NCSERQ = 0
  NCSERS = 0
  NCSERW = 0
  NSERWQ = 0
  NGWSL = 0
  NJEL = 0
  NJPMX = 0
  NLOE = 0
  NLON = 0
  NLOS = 0
  NLOW = 0
  NLRPDRT = 0
  NPORTJP = 0
  NPSERE = 0
  NPSERN = 0
  NPSERS = 0
  NPSERW = 0
  NPSERE1 = 0
  NPSERN1 = 0
  NPSERS1 = 0
  NPSERW1 = 0
  NQCMINS = 0
  NQCMUL = 0
  NQCTLQ = 0
  NQCTYP = 0
  NQSERJP = 0
  NQSERQ = 0
  NQSMF = 0
  NQSMUL = 0
  NQWRSERJP = 0
  NTSCRE = 0
  NTSCRN = 0
  NTSCRS = 0
  NTSCRW = 0
  NTSSSS = 0
  NTVSFP = 0
  NUDJP = 0
  NUDJPC = 0
  IF( ISVEG > 0 )NVEGSERV = 0
  NXYSDAT = 0
  NZPRJP = 0
  
  ! ** TOXIC TRANSPORT VARIABLES
  ISDIFBW = 0
  ISPMXZ = 0
  ISTOC = 0
  ISTOXR = 0
  ITOXBU = 0
  ITOXKIN = 0
  ITOXWU = 0
  ITXBDUT = 0
  ITXINT = 0
  ITXPARB = 0
  ITXPARBC = 0
  ITXPARW = 0
  ITXPARWC = 0
  QCTLGRP = 0

  IF( ISTRAN(5) >= 1 )THEN
    NSP2 = 0
  ENDIF   ! *** END OF TOXIC VARIABLE DECLARATIONS
  
  ! ** SED VARIABLES
  IF( ISTRAN(6) >= 1 )THEN
  ENDIF   ! *** END OF SED VARIABLE DECLARATIONS
  
  ! ** SND VARIABLES
  IF( ISTRAN(7) >= 1 )THEN
  ENDIF   ! *** END OF SND VARIABLE DECLARATIONS
  
  ! *** EITHER SED OR SND
  IBLTAUC = 0
  ISEDWU = 0
  IROUSE = 0
  ISBDLD = 0
  ISEDSCOR = 0
  ISLTAUC = 0
  ISNDEQ = 0
  ISNDM1 = 0
  ISNDM2 = 0
  ISPROBDEP = 0
  IWRSPB = 0

  IF( ISTRAN(6) >= 1 .OR. ISTRAN(7) >= 1 )THEN
    ISEDBU = 0
    ISNDBU = 0
    ISNDWU = 0
    
    ISDBLDIR = 0

    JSS3DSED = 0
    JSS3DSND = 0
    JSS3DTOX = 0

    ! *** BANK EROSION
    IBANKBE = 0
    JBANKBE = 0
    ICHANBE = 0
    JCHANBE = 0
    NBESERN = 0
    MBESER = 0
    MBETLAST = 0
    LPMXZ = 0
  ENDIF
  
  
  ! ** WATER QUALITY VARIABLES
  IF( ISTRAN(8) >= 1 )THEN
    ICPSL = 0
    JCPSL = 0
    KCPSL = 0
    MVPSL = 0
    MWQCTLT = 0

  ENDIF   ! *** END OF WQ VARIABLE DECLARATIONS
  
  IF( ISWQFLUX == 1 )THEN
    ISPV = 0
    IVPV = 0
    JSPV = 0
    JVPV = 0
  ENDIF
  
  IF( ISWASP > 0 )THEN
    LCEFDC = 0
    LCHNC = 0
    NCHNC = 0
  ENDIF
  
  UMASK = 0
  VMASK = 0
  
  ! Begin MHK variables SCJ
  IJLTURB = 0

  ! *** BLOCKED LAYER FACE OPTION
  IF( NBLOCKED > 0 )THEN
    KBBU = 0
    KBBV = 0
    KTBU = 0
    KTBV = 0
    LBLOCKED = 0
  ENDIF

  ! *** ALLOCATE MEMORY FOR VARIABLE TO STORE CONCENTRATIONS AT OPEN BOUNDARIES
  

  ! *** NEW VARIABLES FOR QCTL NQCTYP=3 & 4 
  NLOWCHORD = 0
  
  ! *** SIGMA-ZED - SGZ 
  !@todo put somewhere else.  This subroutine claims to zero out arrays...... but here it is setting to 1
  KSZ  = 1
  KSZU = 1
  KSZV = 1
  IF( IGRIDV > 0 )THEN
    KSZE = 1
    KSZW = 1
    KSZN = 1
    KSZS = 1
  ENDIF
  
  LKSZ = .FALSE.

  ! *** WET/DRY BYPASS VARIABLES
  LWET = 0
  LDRY = 0
  
  ! *** WIND
  IF( NWSER >= 1 )THEN
    ISWDINT = 0
  ENDIF
    
  ! *** ICE
  IF( ISICE > 0 )THEN
    MITLAST = 0
  ENDIF

  ! *** LOGICALS
  LMASKDRY = .FALSE.
  OLDMASK = .FALSE.
  LWVMASK = .FALSE.
  LOPENBCDRY = .FALSE.
  
  ! *** CHARACTER
  CLSL = ' '
  CLTMSR = ' '
  SYMBOL = ' '
  
END
