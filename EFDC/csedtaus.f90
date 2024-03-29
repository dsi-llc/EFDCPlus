! ----------------------------------------------------------------------
!   This file is a part of EFDC+
!   Website:  https://eemodelingsystem.com/
!   Repository: https://github.com/dsi-llc/EFDC_Plus.git
! ----------------------------------------------------------------------
! Copyright 2021-2022 DSI, LLC
! Distributed under the GNU GPLv2 License.
! ----------------------------------------------------------------------
FUNCTION CSEDTAUS(DENBULK,TAUCO,VDRO,VDR,VDRC,IOPT,L)

  ! *** CSEDTAUS RETURNS THE CRITICAL SHEAR STRESS FOR COHESIVE SURFACE EROSION (M^2/S^2)
  ! ***
  ! ***  DENBULK - BULK DENSITY (KG/M^3)
  ! ***  TAUCO   - INPUT OR REFERENCE CRITICAL SHEAR STRESS FOR SURFACE EROSION (M^2/S^2)
  ! ***  VDRO    - REFERENCE VOID RATIO OF THE THE BED      (DIMENSIONLESS)
  ! ***  VDR     - VOID RATIO OF THE TOP LAYER OF THE BED   (DIMENSIONLESS)
  ! ***  VDRC    - VOID RATIO OF THE TOP LAYER OF THE BED   (DIMENSIONLESS)
  
  IMPLICIT NONE

  INTEGER :: L,IOPT
  REAL    :: CSEDTAUS, DENBULK, TAUCO, VDRO, VDR, VDRC
  REAL    :: BULKDEN, TMP

  ! **  IOPT=1  BASED ON
  ! **  HWANG, K. N., AND A. J. MEHTA, 1989: FINE SEDIMENT ERODIBILITY
  ! **  IN LAKE OKEECHOBEE FLORIDA. COASTAL AND OCEANOGRAPHIC ENGINEERING
  ! **  DEPARTMENT, UNIVERSITY OF FLORIDA, GAINESVILLE, FL32661
  IF( IOPT == 1 )THEN
    BULKDEN = 0.001*DENBULK  ! *** TO PREVENT CORRUPTING THE DENBULK VARIABLE
    IF( BULKDEN <= 1.065 )THEN
      CSEDTAUS=1.0E-12
    ELSE
      TMP = (BULKDEN - 1.065)**0.2
      CSEDTAUS = 0.001*(0.883*TMP + 0.05)
    ENDIF

  ! **  IOPT=2  BASED ON J. M. HAMRICK'S MODIFICATION OF
  ! **  SANFORD, L.P., AND J. P. Y. MAA, 2001: A UNIFIED EROSION FORMULATION
  ! **  FOR FINE SEDIMENT, MARINE GEOLOGY, 179, 9-23.
  ELSEIF( IOPT == 2 )THEN
    CSEDTAUS = TAUCO*(1. + VDRO)/(1. + VDR)

  ! *** PMC - 2017-09 - SINCE VDR = VDRC, OPTIONS 2 AND 3 ARE IDENTICAL
  ELSEIF( IOPT == 3 )THEN
    CSEDTAUS = TAUCO*(1. + VDRO)/(1. + VDRC)

  ! **  IOPT=4  BASED ON J. M. HAMRICK'S PARAMETERIZATION OF SEDFLUME TEST DATA
  ELSEIF( IOPT == 4 )THEN
    CSEDTAUS = TAUCO

  ELSEIF( IOPT == 5 )THEN
    CSEDTAUS = TAUCO

  ELSEIF( IOPT == 99 )THEN
    !#######################################################################
    !  HQI ADDED, 11/18/2003, HAMRICK COMMENTED OUT SINCE NOT NEEDED FOR
    !  FOR 11/24 VERSION OF IOPT= 99 THAT IS ACTIVE AS OF 01/08/2004
    !#######################################################################
    !#######################################################################
    !  HQI CHANGE, 08/25/03, AND 11/24/03  SO AND RM
    !  CHANGE TO IMPLEMENT CRITICAL SHEAR STRESS OPTION
    !  CSEDTAUS IS TAU/RHO WITH TAU IN DYNE/CM^2
    !  IWRSP(1) = 99 FOR SHEAR STRESS AS A FUNCTION OF BULK DENSITY FROM
    !                SED-FLUME EXPERIMENTS
    IF( L <= 265 )THEN
      CSEDTAUS = 0.2/1000.
    ELSE
      CSEDTAUS = 0.4/1000.
    ENDIF
  ELSE
    CALL STOPP('CSEDTAUS: BAD SEDIMENT RESUSPENSION OPTION! STOPPING!') 
  ENDIF
  !
  !#######################################################################
  !#######################################################################
  !  HQI ADDED, 11/18/2003
  !  COMPUTE THE D90 OF A CELL BED FROM THE FRACTIONS OF EACH GRAIN SIZE
  !  AND THE COMPUTED D50'S (I.E. THE DEFF FOR THE FOUR CLASSES.
  !      SEDDIA(1)=22.0*1.E-6 !CONVERT MICRON TO METER
  !      UBND = 999.
  !      LBND = -999.
  ! 6400, 570, 160, 63 IN MICRONS
  !        LBND = 0.
  !        LSIZE = 0.
  !  SEDPHIC ** GP-CONVERT SEDIMENT DIAMETERS IN M TO MM AND SET PHI SIZE
  !      SEDDIA(1)=22.0*1.E-6 !CONVERT MICRON TO METER
  ! **  GP - SET MEAN PHI FOR TOP LAYER OF BED
  !      RTVAR3W=0.
  !      RTVAR3E=0.
  !      RSIGPHI=0.
  !        RTVAR3E=1.
  !      ELSE
  !      RSIGPHI=2.**(RSIGPHI)
  ! **  SET MEAN D50
  !      D50SIG=0.
  !      RSNDBT=0.
  !       !D50SIG=D50SIG+SNDB(L,KTOP,NX)*(SEDDIA(NS))
  !      !D50SIG=D50SIG+SEDB(L,KTOP,1)*(SEDDIA(1))
  !      !D50SIG=D50SIG/RSNDBT
  ! ** COMPUTE THE D90 FROM THE STANDARD DEVIATION OF GRAIN SIZE
  !    DISTRIBUTIONIN BED
  !      Z90 = 1.281551  !(Z-SCORE FOR THE 90TH PERCENTILE)
  ! ** COHESIVE CONCENTRATION
  !      COHCON= (SEDB(L,KTOP,1)*1E-6)/HBED(L,KTOP)
  !      CSEDTAUS=(0.36*((D90SIG/D50SIG)**0.948803))
  !        CSEDTAUS = 2./10000.
  !       CALL STOPP('')
  !#######################################################################
  !
  RETURN
END

