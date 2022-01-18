! ----------------------------------------------------------------------
!   This file is a part of EFDC+
!   Website:  https://eemodelingsystem.com/
!   Repository: https://github.com/dsi-llc/EFDC_Plus.git
! ----------------------------------------------------------------------
! Copyright 2021-2022 DSI, LLC
! Distributed under the GNU GPLv2 License.
! ----------------------------------------------------------------------
FUNCTION CSNDZEQ(IOPT, SNDDIA, GPDIASED, TAUR, TAUB, SNDDMX, DEP, SSG, WS)  

  ! *** CALCULATES NEAR BED REFERENCE CONCENTRATION REFERENCE HEIGHT (DIMENSIONLESS) 
  ! 
  ! CHANGE RECORD  
  ! DATE MODIFIED     BY               DESCRIPTION
  !----------------------------------------------------------------------!
  ! 2011-03           PAUL M. CRAIG    REWRITTEN TO F90
  ! 2011-03-02        PAUL M. CRAIG    FIXED CASE WHEN WS <= 0
  
  IMPLICIT NONE
  
  INTEGER :: IOPT
  REAL    :: CSNDZEQ, SNDDIA, GPDIASED, TAUR, TAUB, SNDDMX, DEP, SSG, WS, TMPVAL, REY
  REAL    :: TAURS, VAL, VAL1, ZEQ1

  
  IF( IOPT == 1 )THEN  
    ! *** IOPT=1  BASED ON  
    ! *** 
    ! *** GARCIA, M., AND G. PARKER, 1991: ENTRAINMENT OF BED SEDIMENT  
    ! *** INTO SUSPENSION, J. HYDRAULIC ENGINEERING, 117, 414-435.  

    CSNDZEQ = 0.05  

  ELSEIF( IOPT == 2 )THEN  
    !  
    ! *** IOPT=2  BASED ON  
    ! *** 
    ! *** SMITH, J. D., AND S. R. MCLEAN, 1977: SPATIALLY AVERAGED FLOW  
    ! *** OVER A WAVY SURFACE, J. GEOPHYSICAL RESEARCH, 82, 1735-1746.  

    TMPVAL = 26.3*SNDDMX*(TAUB-TAUR)/GPDIASED  
    TMPVAL = TMPVAL*SNDDIA/SNDDMX  
    TMPVAL = TMPVAL/DEP  
    CSNDZEQ = MAX(TMPVAL,0.01)  

  ELSEIF( IOPT == 3 )THEN
    ! *** IOPT=3  BASED ON  
    ! *** 
    ! *** VAN RIJN, L. C., 1984: SEDIMENT TRANSPORT, PART II: SUSPENDED  
    ! *** LOAD TRANSPORT, J. HYDRAULIC ENGINEERING, 110, 1623-1641.  
    IF( WS > 0. )THEN
      REY = 1.E4*SNDDIA*( (9.8*(SSG-1.))**0.333 ) 
      IF( REY <= 10. ) TAURS = (4.*WS/REY)**2  
      IF( REY  > 10. ) TAURS = 0.16*WS*WS                      ! *** Corrected 2021-06 from 0.016.  0.16 = 0.4^2 from VanRijn 1984
      VAL = (TAUB/TAURS)-1.  
      VAL = MIN(MAX(VAL,0.),100.)  
      VAL1 = 1.-EXP(-0.5*VAL)  
      VAL1 = 0.11*VAL1*(25.-VAL)  
      ZEQ1 = 0.5*VAL1*(DEP**0.7)*(SNDDMX**0.3)  
      ZEQ1 = ZEQ1/DEP  
      CSNDZEQ = MAX(ZEQ1,0.01) 
    ELSE
      CSNDZEQ = 0.01
    ENDIF

  ELSEIF( IOPT  ==  4 .OR. IOPT == 5 )THEN
    ! *** HAMRICK'S SEDFLUME OPTION
    CSNDZEQ = 0.01

  ELSE
    ! *** BAD OPTION
    CALL STOPP('BAD CSNDZEQ OPTION') 

  ENDIF  

  RETURN  

END  

