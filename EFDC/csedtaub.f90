! ----------------------------------------------------------------------
!   This file is a part of EFDC+
!   Website:  https://eemodelingsystem.com/
!   Repository: https://github.com/dsi-llc/EFDC_Plus.git
! ----------------------------------------------------------------------
! Copyright 2021-2022 DSI, LLC
! Distributed under the GNU GPLv2 License.
! ----------------------------------------------------------------------
FUNCTION CSEDTAUB(DENBULK,IOPT)

  ! **  CALCULATES CRITICAL STRESS FOR BULK OR MASS EROSION OF COHESIVE
  ! **  SEDIMENT AS A FUNCTION OF BED BULK DENSITY
  ! **
  ! **  IOPT=1  BASED ON
  ! **  HWANG, K. N., AND A. J. MEHTA, 1989: FINE SEDIMENT DRODIBILITY
  ! **  IN LAKE OKEECHOBEE FLORIDA. COASTAL AND OCEANOGRAPHIC ENGINEERING
  ! **  DEPARTMENT, UNIVERSITY OF FLORIDA, GAINESVILLE, FL32661
  ! **
  ! **  IOPT=2  BASED ON
  ! **  HWANG, K. N., AND A. J. MEHTA, 1989: FINE SEDIMENT DRODIBILITY
  ! **  IN LAKE OKEECHOBEE FLORIDA. COASTAL AND OCEANOGRAPHIC ENGINEERING
  ! **  DEPARTMENT, UNIVERSITY OF FLORIDA, GAINESVILLE, FL32661

  ! CHANGE RECORD

  IMPLICIT NONE
  
  INTEGER :: IOPT
  REAL    :: CSEDTAUB, DENBULK, BULKDEN

  IF( IOPT == 1 )THEN
    BULKDEN = 0.001*DENBULK  ! *** PMC Changed to prevent
    IF( BULKDEN <= 1.013 )THEN
      CSEDTAUB=0.0
    ELSE
      CSEDTAUB = 0.001*(9.808*BULKDEN-9.934)
    ENDIF
  ELSEIF( IOPT == 2 )THEN
    BULKDEN = 0.001*DENBULK  ! *** PMC Changed to prevent
    IF( BULKDEN <= 1.013 )THEN
      CSEDTAUB = 0.0
    ELSE
      CSEDTAUB = 0.001*(9.808*BULKDEN-9.934)
    ENDIF
  ELSE
    CALL STOPP('CSEDTAUB: BAD SEDIMENT CRITICAL STRESS OPTION! STOPPING!')
  ENDIF

END FUNCTION

