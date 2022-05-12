! ----------------------------------------------------------------------
!   This file is a part of EFDC+
!   Website:  https://eemodelingsystem.com/
!   Repository: https://github.com/dsi-llc/EFDC_Plus.git
! ----------------------------------------------------------------------
! Copyright 2021-2022 DSI, LLC
! Distributed under the GNU GPLv2 License.
! ----------------------------------------------------------------------
FUNCTION CSNDEQC(IOPT,SNDDIA,SSG,WS,TAUR,TAUB,D50,SIGPHI,SNDDMX,VDR,ISNDAL)  

  ! *** CALCULATES NEAR BED REFERENCE CONCENTRATION FOR NONCOHESIVE SEDIMENT  
  ! 
  ! CHANGE RECORD  
  ! DATE MODIFIED     BY               DESCRIPTION
  !----------------------------------------------------------------------!
  ! 2011-03-02        PAUL M. CRAIG    FIXED CASE WHEN WS <= 0
  !                   JOHN HAMRICK     IF USTAR < WS SET EQUILBRIUM NEAR BED CONCENTRATION TO ZERO
  !                                    TRANSPORT VIA BED LOAD IMPLEMENTED IN SSEDTOX FOR 
  !                                    USTAR**2 > CRITICAL SHIELDS AND USTAR < WS

  !     SNDDIA = SAND GRAIN DIAMETER 
  !     SSG    = SAND GRAIN SPECIFIC GRAVITY 
  !     WS     = SAND GRAIN SETTLING VELOCITY
  !     TAUR   = WATER DENSITY NORMALIZED CRITICAL SHIELDS STRESS
  !     TAUB   = WATER DENSITY NORMALIZED BED STRESS
  !     SSG    = SAND SPECIFIC GRAVITY 
  !     SIGPHI = PHI SIZE STANDARD DEVIATION
  !     SNDDMX = D90 SEDIMENT DIAMETER OR MAX SEDIMENT DIAMETER
  !
  
  IMPLICIT NONE
  INTEGER :: IOPT,ISNDAL
  REAL :: CSNDEQC,SNDDIA,SSG,WS,TAUR,TAUB,D50,SIGPHI,SNDDMX,VDR,USTAR
  REAL :: REY,DFAC,RLAM,VAL,TMP,TAURS,REY3,RATIO,TMPVAL
  
  USTAR = SQRT(TAUB)
  
  IF( USTAR < WS )THEN
     CSNDEQC = 0.
     
  ELSEIF( IOPT == 1 )THEN  
    ! *** IOPT = 1  BASED ON  
    ! *** 
    ! *** GARCIA, M., AND G. PARKER, 1991: ENTRAINMENT OF BED SEDIMENT  
    ! *** INTO SUSPENSION, J. HYDRAULIC ENGINEERING, 117, 414-435.  

    IF( WS > 0. )THEN
      REY = 1.E6*SNDDIA*SQRT( 9.8*(SSG-1.)*SNDDIA )   !EQ 42
      REY = REY**0.6                                  !SEE EQ 43
      DFAC = 1.
      IF( ISNDAL >= 1) DFAC = (SNDDIA/D50)**0.2       !SEE EQ 43
      RLAM = 1.-0.29*SIGPHI                           !EQ 51
      VAL = DFAC*RLAM*REY*USTAR/WS                    !Z IN EQ 43
      VAL = 1.3E-7*(VAL**5)                           !TOP OF EQ 45
      TMP = VAL/(1+3.33*VAL)                          !EQ 45
      CSNDEQC = 1.E6*SSG*TMP                          !CONVERT TO MASS CONC
    ELSE
      CSNDEQC = 0.
    ENDIF

  ELSEIF( IOPT == 2 )THEN  
    ! *** IOPT = 2  BASED ON  
    ! *** 
    ! *** SMITH, J. D., AND S. R. MCLEAN, 1977: SPATIALLY AVERAGED FLOW  
    ! *** OVER A WAVY SURFACE, J. GEOPHYSICAL RESEARCH, 82, 1735-1746.  

    VAL = 2.4E-3*( (TAUB/TAUR)-1. )  
    VAL = MAX(VAL,0.)  
    TMP = 0.65*VAL/(1.+VAL)  
    CSNDEQC = 1.E6*SSG*TMP  

  ELSEIF( IOPT == 3 )THEN
    ! *** IOPT = 3  BASED ON  
    ! *** 
    ! *** VAN RIJN, L. C., 1984: SEDIMENT TRANSPORT, PART II: SUSPENDED  
    ! *** LOAD TRANSPORT, J. HYDRAULIC ENGINEERING, 110, 1623-1641.  

    IF( WS > 0. )THEN
      REY = 1.E4*SNDDIA*( (9.8*(SSG-1.))**0.333 )  
      IF( REY <= 10. ) TAURS = (4.*WS/REY)**2  
      IF( REY  > 10. ) TAURS = 0.16*WS*WS                      ! *** Corrected 2021-06 from 0.016.  0.16 = 0.4^2 from VanRijn 1984
      REY3 = REY**0.3  
      VAL = (TAUB/TAURS)-1.  
      VAL = MAX(VAL,0.)  
      VAL = VAL**1.5  
      RATIO = SNDDIA/(3.*SNDDMX)  
      TMP = 0.015*RATIO*VAL/REY3  
      CSNDEQC = 1.E6*SSG*TMP  
    ELSE
      CSNDEQC = 0.
    ENDIF
    
  ELSEIF( IOPT == 4 )THEN

    ! *** IOPT = 4  BASED ON 
    ! **
    ! *** J.M. HAMRICK'S PARAMETERIZATION OF SEDFLUME DATA NO CRITICAL STRESS
    IF( WS > 0. )THEN
      REY = 1.E4*SNDDIA*( (9.8*(SSG-1.))**0.333 )
      TMPVAL = SQRT(TAUB)/WS
      REY3 = REY**1.333
      TMPVAL = REY3*TMPVAL
      VAL = (TMPVAL-1.0)**5.
      VAL = 4.E-9*VAL
      CSNDEQC = 1.E6*SSG*VAL/(1.+VDR)
    ELSE
      CSNDEQC = 0.
    ENDIF

  ELSEIF( IOPT == 5 )THEN
    ! *** IOPT = 5  BASED ON 
    ! **
    ! *** J.M. HAMRICK'S PARAMETERIZATION OF SEDFLUME DATA WITH CRITICAL STRESS
    IF( WS > 0. )THEN
      REY = 1.E4*SNDDIA*( (9.8*(SSG-1.))**0.333 )
      TMPVAL = SQRT(TAUB)/WS
      REY3 = REY**1.333
      TMPVAL = REY3*TMPVAL
      VAL = 0.0
      IF( TMPVAL > 1.0 ) VAL = (TMPVAL-1.0)**5.
      VAL = 4.E-9*VAL
      CSNDEQC = 1.E6*SSG*VAL/(1.+VDR)
    ELSE
      CSNDEQC = 0.
    ENDIF
  ELSE
    ! *** BAD OPTION
    CALL STOPP('BAD CSNDEQC OPTION') 
  ENDIF

  RETURN  
  END  

