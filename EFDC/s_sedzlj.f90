! ----------------------------------------------------------------------
!   This file is a part of EFDC+
!   Website:  https://eemodelingsystem.com/
!   Repository: https://github.com/dsi-llc/EFDC_Plus.git
! ----------------------------------------------------------------------
! Copyright 2021-2022 DSI, LLC
! Distributed under the GNU GPLv2 License.
! ----------------------------------------------------------------------
SUBROUTINE SEDZLJ(L)
  
  ! CALCULATES DEPOSITION, ENTRAINMENT, NET FLUX, TOTAL THICKNESS,
  ! LAYER ORDER, AND COMPONENT LAYER FRACTION
  ! UCSB, Craig Jones and Wilbert Lick

  ! ORIGINAL:  May 24, 2006
  ! REVISION DATE :  August 29th, 2007
  !  Craig Jones and Scott James
  !  Updated to fix Active Layer issues

  ! 2016-11-07  Paul M. Craig  Updated for SIGMA-ZED AND OMP
  ! 2017-01-04  Paul M. Craig  Toxics and bedload mass balance updates
  ! 2021-06-07  Paul M. Craig  Updated for propwash

  USE GLOBAL
  USE FIELDS
  Use Variables_Propwash
  
  IMPLICIT NONE
  
  INTEGER :: K, NS, L, SURFACE, SLLN, NACTLAY, NT, K1, SURFOLD
  INTEGER :: NSC0, NSC1, NTAU0, NTAU1, ICORE

  REAL(RKD) :: CSEDSS,SQR2PI
  REAL(RKD) :: D50TMPP
  REAL(RKD) :: DEP
  REAL(RKD) :: EBD
  REAL(RKD) :: ERATEMOD
  REAL(RKD) :: ERO
  REAL(RKD) :: NSCTOT
  REAL(RKD) :: ONE=1.0
  REAL(RKD) :: PFY
  REAL(RKD) :: PX
  REAL(RKD) :: PY
  REAL(RKD) :: SEDFLUX
  REAL(RKD) :: SN00
  REAL(RKD) :: SN01
  REAL(RKD) :: SN10
  REAL(RKD) :: SN11
  REAL(RKD) :: TEMP,TEMP1,TEMP2
  REAL(RKD) :: TACT,TSUM
  REAL(RKD) :: TAUCRIT
  REAL(RKD) :: VZDIF
  REAL(RKD) :: WDTDZ
  
  REAL(RKD) ,DIMENSION(NSCM) :: QBFLUX
  REAL(RKD) ,DIMENSION(NSCM) :: CSEDVR
  REAL(RKD) ,DIMENSION(NSCM) :: CTB
  REAL(RKD) ,DIMENSION(NSCM) :: DEPBL
  REAL(RKD) ,DIMENSION(NSCM) :: DEPTSS
  REAL(RKD) ,DIMENSION(NSCM) :: ELAY
  REAL(RKD) ,DIMENSION(NSCM) :: ETOT
  REAL(RKD) ,DIMENSION(NSCM) :: PROB
  REAL(RKD) ,DIMENSION(NSCM) :: PROBVR
  REAL(RKD) ,DIMENSION(NSCM) :: SMASS
  REAL(RKD) ,DIMENSION(NSCM) :: TTEMP
  REAL(RKD) ,DIMENSION(KB)   :: INITMASS
  
  REAL(RKD) ,DIMENSION(2)    :: NSCD
  REAL(RKD) ,DIMENSION(2)    :: TAUDD

  ! *** *******************************************************************
  ICORE = NCORENO(IL(L),JL(L))
  
  ! *** CALCULATE EROSION/DEPOSITION FOR TOP LAYER FOR ALL CELLS
  ETOTO(L) = 0.0          ! *** Initialize total erosion for the cell
  QBLFLUX(L,1:NSCM) = 0.0 ! *** Initialize bedload flux

  DEP = 0.0               ! *** Initialize no total deposition for the cell
  DEPTSS(1:NSCM) = 0.0    ! *** Initialize deposition from suspended load
  DEPBL(1:NSCM) = 0.0     ! *** Initialize deposition from bedload
  PROB(1:NSCM) = 0.0      ! *** Initialize probability of deposition of suspended load
  
  INITMASS(1:KB) = TSED(1:KB,L)   ! *** Save the starting sediment mass by layers
  SQR2PI = 1. / SQRT(2.*PI)
  
  ! *** Convert Bottom Shear from (m/s)^2 to dynes/cm^2, if using shear from EFDC
  !     TAU(L)=TAUBSED(L)*1000.0*10.0

  ! *** Convert Bottom Concentrations and estimate bottom concentration for KC=1
  IF( KSZ(L) == KC )THEN    ! *** Alberta
    ! *** Estimate bottom concentration assuming exponential sediment concentration profile in single layer
    USTAR(L) = SQRT(TAU(L)/10000.0)                                     ! *** USTAR m/s
    DO NS=1,NSCM
      VZDIF = MAX(20.0,0.067*HPCM(L)*USTAR(L)*100._8)                   ! *** Convert units of USTAR to cm/s
      TEMP2 = HPCM(L)*DWS(NS)/VZDIF
      CTB(NS) = SED(L,KSZ(L),NS)*TEMP2*(ONE/(ONE-EXP(-TEMP2)))*1.0D-06  ! *** Convert Bottom Concentration from mg/L (g/m^3) to g/cm^3
    ENDDO
  ELSE
    CTB(1:NSCM) = SED(L,KSZ(L),1:NSCM)*1.0D-06                          ! *** Convert Bottom Concentration from mg/L (g/m^3) to g/cm^3
  ENDIF
  
  ETOT(1:NSCM)  = 0.0   ! *** Initialize erosion rates for each size class and each cell
  ELAY(1:NSCM)  = 0.0   ! *** Initialize top-layer erosion rates for each sediment size class
  SMASS(1:NSCM) = 0.0   ! *** Initializes bedload sediment mass available for deposition  (g/cm^2)
  
  ! *** ********************************************************************************************************************************************
  ! CALCULATE DEPOSITION
  ! *** Temporarily calculate the sediment mass in the active layer (g/cm^3)
  ! *** so that percentages can be determined after deposition.
  
  ! *** Deposition from suspended load by sediment sizes
  DO NS=1,NSCM
    ! *** If there is no sediment of that size available in the water column then it cannot be deposited
    IF( CTB(NS) < 1.0E-20 ) CYCLE                                      

    ! *** Calculate probability for suspended load deposition
    ! *** Based on Gessler (1965) if D50 > 200um or Krone if < 200 um  (SNL Eqs 15 - 18)
    IF( PROP_ERO(L,0) > 0. )THEN
      PROB(NS) = 0.0                                                ! *** Zero probability when propeller wash is active
    ELSEIF( D50(NS) >= BEDLOAD_CUTOFF )THEN
      PY  = 1.7544*(TCRSUS(NS)/(TAU(L) + 1.0D-18)-ONE)              ! *** 1.7544 = 1/sigma =  1./0.57 from Gessler
      IF( PY >= 0.0 )THEN
        PFY = SQR2PI*EXP(-0.5d0*PY*PY)
        PX  = ONE/(ONE + 0.33267*PY)
        PROB(NS) = ONE - PFY*(0.43618*PX - 0.12016*PX*PX + 0.93729*PX**3)
      ELSE
        PY  = DABS(PY)
        PFY = SQR2PI*EXP(-0.5d0*PY*PY)
        PX  = ONE/(ONE + 0.33267*PY)
        PROB(NS) = PFY*(0.43618*PX - 0.12016*PX*PX + 0.93729*PX**3)
      ENDIF
    ELSEIF( TAU(L) <= TCRSUS(NS) )THEN
      PROB(NS) = ONE - TAU(L)/(TCRSUS(NS))                          ! *** Krones deposition probability is calculated
    ELSE
      PROB(NS) = 0.0                                                ! *** Zero probability when TAU > TCRSUS
    ENDIF
     
    ! *** Calculate SMASS of sediment present in water and allow only that much to be deposited.
    SMASS(NS)  = SED(L,KSZ(L),NS)*1.0D-06*DZC(L,KSZ(L))*HPCM(L)*MAXDEPLIMIT     ! *** SMASS(NS) is the total sediment mass in the first layer.  It is calculated as a precaution so that no more than the total amount of mass in the first layer can deposit onto the sediment bed PERSED time step.
    DEPTSS(NS) = CTB(NS)*PROB(NS)*(DWS(NS)*DTSEDJ)                              ! *** Deposition of a size class is equal to the probability of deposition times the settling rate times the time step times the sediment concentration
  ENDDO
  DEPTSS(1:NSCM) = MIN(MAX(DEPTSS(1:NSCM),0.0),SMASS(1:NSCM))       ! *** Do not allow more sediment to deposit than is available in the water-column layer above the bed

  ! *** Deposition from Bedload
  IF( ICALC_BL > 0 .AND. PROP_ERO(L,0) == 0.0 )THEN
    DO NS=1,NSCM
      IF( D50(NS) < BEDLOAD_CUTOFF ) CYCLE

      IF( CBL(L,NS) < 1E-20 ) CYCLE
      SMASS(NS) = CBL(L,NS)                                   ! *** Local mass available for deposition is the bedload concentration times the bedload height
      CSEDSS = SMASS(NS)/(DWS(NS)*DTSEDJ)                     ! *** Concentration eroded into bedload from the last time step
      CSEDVR(NS) = (0.18*2.65*TRANS(L,NS)/DISTAR(NS)*0.65)    ! *** van Rijn's (1981, Eq. 21) equilibrium bedload concentration (here TRANS is the transport parameter for bedload calculations)
      IF( CSEDVR(NS) <= 0.0 )THEN                             ! *** If there is no equilibrium bedload available
        PROBVR(NS) = 1.0                                      ! *** then deposition probability is unity
      ELSE
        PROBVR(NS) = MIN(CSEDSS/CSEDVR(NS),1.0)               ! *** van Rijn probability of deposition from bedload
      ENDIF
      IF( CSEDSS <= 0.0 ) PROBVR(NS) = PROB(NS)               ! *** In case CBL = 0  The deposition from bedload reverts to Gessler's for that particle size.
      
      DEPBL(NS) = PROBVR(NS)*CBL(L,NS)*(DWS(NS)*DTSEDJ)       ! *** Calculate Bedload Deposition (DEPBL)  (g/cm^2)
                                                              ! *** Deposition from bedload is the van Rijn probability times bedload concentration time settling velocity times the time step
      DEPBL(NS) = MIN(MAX(DEPBL(NS),0.0),SMASS(NS))           ! *** Do not allow more bedload deposition than bedload mass available
    ENDDO
    DEP = SUM(DEPBL(1:NSCM)) + SUM(DEPTSS(1:NSCM))            ! *** Total deposition, sum of bedload and suspended load deposition for all size classes
  ELSE
    DEP = SUM(DEPTSS(1:NSCM))                                 ! *** Total deposition is the sum of suspended load deposition for all size classes
  ENDIF
  
  ! *** TOTAL DEPOSITION
  DEPO(L) = DEP/DTSEDJ                                        ! *** Calculate the deposition rate (g/cm^2/s)
  
  ! *** ********************************************************************************************************************************************
  ! *** Get things set up for Erosion Calculations
  ! *** Find the next layer (SLLN) of sediment below the top layer based on the LAYERACTIVE from the previous time step
  SLLN = KB
  IF( LAYERACTIVE(2,L) == 1 )THEN   ! *** Check to ensure that there are at least 2 sediment layers present here
    SLLN = 2                        ! *** Layer number below active layer (always 3 to start after SEDIC, always 2 when there at least 2 layers)
  ELSE
    DO K=3,KB
      IF( LAYERACTIVE(K,L) > 0 .AND. LAYERACTIVE(K-1,L) == 0 )THEN
        SLLN = K                      ! *** Next layer is renumbered as necessary (happens if active layer is eroded completely)
        EXIT
      ENDIF
    ENDDO
  ENDIF
  
  ! *** Calculate Average particle size of surface layer so we can calculate
  ! *** active layer unit mass
  IF( LAYERACTIVE(1,L) == 1 )THEN
    SURFACE = 1                     ! *** Surface variable set to top layer
  ELSE
    SURFACE = SLLN                  ! *** Otherwise the top layer is SLLN
  ENDIF
  D50AVG(L) = SUM(PERSED(1:NSCM,SURFACE,L)*D50(1:NSCM))             ! *** Calculate local d50 at sediment bed surface
 
  ! *** Calculate TAUCRIT Based on the Average Particle Size of Surface
  ! *** Then calculate the Active Layer unit mass (TACT) from it.
  ! *** Ta =  Tam * Davg * (Tau/Taucr)
  TAUCRIT = 1.E6
  IF( LAYERACTIVE(SURFACE,L) == 1 )THEN
    ! *** Active/deposited layer
    IF(D50AVG(L) < SCND(1) )THEN
      NSCD(1)=SCND(1)
      NSCD(2)=SCND(2)
      NSC0=1
      NSC1=2
      D50AVG(L) = SCND(1)                                             ! *** Prevent division (s_shear) by zero when there is no sediment in the layer 
    ELSEIF( D50AVG(L) >= SCND(NSICM) )THEN
      NSCD(1)=SCND(NSICM-1)
      NSCD(2)=SCND(NSICM)
      NSC0=NSICM-1
      NSC1=NSICM
    ELSE  
      DO NS=1,NSICM-1
        IF( D50AVG(L) >= SCND(NS) .AND. D50AVG(L) < SCND(NS+1) )THEN
          NSCD(1)=SCND(NS)
          NSCD(2)=SCND(NS+1)
          NSC0=NS
          NSC1=NS+1
          EXIT
        ENDIF
      ENDDO
    ENDIF
  
    TAUCRIT = TAUCRITE(NSC0)+(TAUCRITE(NSC1)-TAUCRITE(NSC0))/(NSCD(2)-NSCD(1))*(D50AVG(L)-NSCD(1))
    TAUCOR(SURFACE,L) = TAUCRIT
  ELSEIF( LAYERACTIVE(SURFACE,L) == 2 )THEN
    ! *** In-place sediment layer
    TAUCRIT = TAUCOR(SURFACE,L)
  ENDIF
  
  ! *** Compute the requried active layer thickness (cm)
  IF( TAU(L)/TAUCRIT < 1.0 )THEN
    TACT = TACTM*D50AVG(L)*(BULKDENS(1,L)/10000.0)
  ELSE
    TACT = TACTM*D50AVG(L)*(TAU(L)/TAUCRIT)*(BULKDENS(1,L)/10000.0)
  ENDIF

  ! *** This is where we determine if there is an un-erodeable size class.  
  ! *** If there is one, we need an active layer.
  NACTLAY = 0
  DO K=1,KB                            ! *** Search through all layers
    IF( LAYERACTIVE(K,L) > 0 )THEN     ! *** If the layer is present
      DO NS=1,NSCM
        ! *** TAU is > the critical shear stress for erosion based on the d50 but less than the critical shear stress for one or more size classes
        IF( PERSED(NS,K,L) > 0.0 .AND. TAU(L) < TCRE(NS) .AND. TAU(L) > TAUCRIT )THEN !if the size class is present and the sediment bed is eroding and there is insufficient shear stress for suspension
          NACTLAY = 1                  ! *** There is an active layer (logical variable)
          LAYERACTIVE(1,L) = 1         ! *** There is an active layer
          EXIT
        ENDIF
      ENDDO
    ENDIF
  ENDDO

  ! *** If the layer exposed can erode, then 
  ! *** use the active layer model, otherwise just put deposited material
  ! *** on top.  Also if there is a size class present in the top layer
  ! *** that will not erode, create an active layer.
  SURFOLD = 0
  IF( TSED(1,L) > 0.0 .OR. NACTLAY /= 0 )THEN      ! *** If there is mass in the active layer, we must go through the sorting routine
    ! *** No active layer for pure erosion (active layer needed for coarsening and deposition)
  
    ! *** Sort layers so that the active layer is always Ta thick.
    ! *** Recalculate the mass fractions after borrowing from lower layers
    IF( LAYERACTIVE(1,L) == 1 )THEN
      IF( TSED(1,L) > TACT )THEN                        ! *** At this point TSED does not include the deposited sediment for this time step            
        ! *** There is deposition over this time step.  Redistribute excess mass to the deposition layer (i.e. layer 2)
        FORALL(NS=1:NSCM)PERSED(NS,2,L)=(PERSED(NS,2,L)*TSED(2,L)+PERSED(NS,1,L)*(TSED(1,L)-TACT))/(TSED(2,L)+(TSED(1,L)-TACT))  ! *** Recalculate mass fractions
        LAYERACTIVE(2,L) = 1                            ! *** Ensure that the second layer logical is turned on
        SLLN = 2                                        ! *** Next lower layer is 2
        TSED(2,L) = TSED(2,L) + TSED(1,L) - TACT        ! *** Add layer unit mass in excess of active-layer unit mass to next lower layer
        TSED(1,L) = TACT                                ! *** Reset top layer unit mass to active layer unit mass
        
      ELSEIF( TSED(1,L) < TACT .AND. TSED(1,L)+TSED(SLLN,L) > TACT .AND. TAU(L) > TAUCOR(SLLN,L) )THEN
        ! *** There is net erosion over this time step and there is sufficient sediment below to reconstitute the active layer
        FORALL(NS=1:NSCM) PERSED(NS,1,L) = (PERSED(NS,1,L)*TSED(1,L) + PERSED(NS,SLLN,L)*(TACT-TSED(1,L)))/TACT     ! *** Recalculate the mass fraction
        TSED(SLLN,L) = TSED(SLLN,L) - (TACT-TSED(1,L))  ! *** Borrow unit mass from lower layer
        TSED(1,L) = TACT                                ! *** Reset top layer unit mass to active layer unit mass
        
      ELSEIF( TSED(1,L) < TACT .AND. TSED(1,L)+TSED(SLLN,L) <= TACT .AND. TAU(L) > TAUCOR(SLLN,L) )THEN
        ! *** There is net erosion over this time step and there is NOT sufficient sediment below to reconstitute the active layer
        FORALL(NS=1:NSCM)
          PERSED(NS,1,L) = (PERSED(NS,1,L)*TSED(1,L) + PERSED(NS,SLLN,L)*(TSED(SLLN,L)))/(TSED(1,L) + TSED(SLLN,L))  ! *** Recalculate the mass fraction
          PERSED(NS,SLLN,L) = 0.0                       ! *** No more sediment available in next lower layer
        ENDFORALL
        TSED(1,L) = TSED(1,L) + TSED(SLLN,L)            ! *** Add available sediment to layer
        SURFOLD = KBT(L)                                ! *** Save the residual layer
        TSED(SLLN,L) = 0.0                              ! *** No more sediment available below this
        LAYERACTIVE(SLLN,L) = 0                         ! *** Layer has been eliminated in the logical variable
        IF( SLLN < KB )THEN
          SLLN = SLLN + 1                               ! *** Set next layer lower
          DO WHILE (TSED(SLLN,L) <= 0. )
            SLLN = SLLN + 1                                 
            IF( SLLN > KB )THEN
              SLLN = KB                                 ! *** Do not allow specification of the next lower layer to be below the bottom sediment layer
              EXIT
            ENDIF
          ENDDO
        ENDIF
      ENDIF
    ENDIF
  ENDIF

  ! *** Propwash
  IF( NACTIVESHIPS > 0 )THEN                                                              ! *** Propwash is active and there are active ships. 
    PROP_ERO(L,1:NSCM) = PROP_ERO(L,1:NSCM)/DXYP(L)/10000.                                ! *** Convert mass from g to g/cm^2
  ENDIF

  ! *** ********************************************************************************************************************************************
  ! *** Now calculate the Erosion Rates
  K1 = 0
  DO K=1,KB                                          ! *** Loop through all sediment layers so that they are properly eroded and sorted
    IF( LAYERACTIVE(K,L) == 0 ) CYCLE                ! *** If the layer is gone don't consider it
    IF( LAYERACTIVE(1,L) == 1 .AND. K /= 1 )THEN
      if( PROP_ERO(L,0) == 0.0 ) EXIT                ! *** If it is depositional, there is no need to consider erosion.  Don't exit if propwash is active
    ENDIF
    IF( K > 1 )THEN
      IF( LAYERACTIVE(K-1,L) > 0 )THEN
        EXIT                                         ! *** Exit loop if layer above still has mass (i.e. not eroded completely, so erosion flux satisfied)
      ENDIF
    ENDIF

    D50AVG(L) = SUM(PERSED(1:NSCM,K,L)*D50(1:NSCM))  ! *** Find mean diameter of Layer
    
    ! *** Find upper and lower limits of size classes on mean bed diameter
    IF( (D50AVG(L)+1E-6) < SCND(1) )THEN
      IF( TSED(k,L) > 1E-8 )THEN
        PRINT '("Limits!  L: ",I6,", K: ", I3,", BED MASS: ",E14.6,", COMPUTED D50: ",f10.4,", MIN GRAINSIZE: ",F10.4)', Map2Global(L).LG, K, TSED(K,L), D50AVG(L), SCND(1)
        IF( TSED(K,L) > 1E-4 )THEN
          CALL STOPP('COMPUTED BED D50 < MINIMUM BED GRAINSIZE CLASS!')
        ELSE
          PERSED(1:NSCM,K,L) = 0.0
          PERSED(1,K,L) = 1.0
          NS = 1
          NSCD(1) = SCND(NS)
          NSCD(2) = SCND(NS+1)
          NSC0 = NS
          NSC1 = NS+1
          D50AVG(L) = SCND(1)
        ENDIF
      ELSE
        PERSED(1:NSCM,K,L) = 1./FLOAT(NSCM)
        D50AVG(L)=SUM(PERSED(1:NSCM,K,L)*D50(1:NSCM))
      ENDIF
    ELSEIF( (D50AVG(L)-1E-6) > SCND(NSICM) )THEN
      IF( TSED(k,L) > 1E-8 )THEN
        PRINT '("Limits!  L: ",I6,", K: ", I3,", BED MASS: ",E14.6,", COMPUTED D50: ",f10.4,", MAX GRAINSIZE: ",F10.4)', Map2Global(L).LG, K, TSED(K,L), D50AVG(L), SCND(NSICM)
        IF( TSED(K,L) > 1E-4 )THEN
          CALL STOPP('COMPUTED BED D50 > MAXIMUM BED GRAINSIZE CLASS!')
        ELSE
          PERSED(1:NSCM,K,L) = 0.0
          PERSED(NSCM,K,L) = 1.0
          NS = NSICM - 1
          NSCD(1) = SCND(NS)
          NSCD(2) = SCND(NS+1)
          NSC0 = NS
          NSC1 = NS+1
          D50AVG(L) = SCND(NSICM)
        ENDIF
      ELSE
        PERSED(1:NSCM,K,L) = 1./FLOAT(NSCM)
        D50AVG(L)=SUM(PERSED(1:NSCM,K,L)*D50(1:NSCM))
      ENDIF
    ELSE   
      DO NS=1,NSICM-1
        IF( D50AVG(L) >= SCND(NS) .AND. D50AVG(L) < SCND(NS+1) )THEN
          NSCD(1)=SCND(NS)
          NSCD(2)=SCND(NS+1)
          NSC0=NS
          NSC1=NS+1
          EXIT
        ENDIF
      ENDDO
    ENDIF
    
    ! *** Calculate TAUCRIT Based on the D50 of the bed or from Sedflume Data
    IF( LAYERACTIVE(K,L) == 1 )THEN
      ! *** For active layers
      TAUCRIT = TAUCRITE(NSC0) + (TAUCRITE(NSC1)-TAUCRITE(NSC0))/(NSCD(2)-NSCD(1))*(D50AVG(L)-NSCD(1)) !interpolation
      TAUCOR(K,L) = TAUCRIT
    ELSEIF( LAYERACTIVE(K,L) == 2 )THEN         ! *** IC Bed sediments
      ! *** SEDFlume data (depth interpolation)
      SN01 = TSED(K,L)/TSED0(K,L)               ! *** Weighting factor 1 for interpolation
      SN11 = (TSED0(K,L)-TSED(K,L))/TSED0(K,L)  ! *** Weighting factor 2
      TAUCRIT = SN01*TAUCOR(K,L) + SN11*TAUCOR(K+1,L)
    ENDIF
    ERO = 0.                                    ! *** Total erosion from the layer
    
    ! *** Check if the shear is greater than critical shears.  If not, exit erosion loop
    IF( TAU(L) < SH_SCALE(L)*TAUCRIT .AND. PROP_ERO(L,0) == 0.0 )THEN
      EXIT
    ENDIF
    
    ! *** Now, calculate erosion rates  ----------------------------------------------------------------------------------
    ! *** Find the upper and lower limits of the Shear Stress for the interpolation
    IF( TAU(L) >= TAULOC(ITBM) )THEN
      IF( NWARNING < 100 )THEN
        PRINT '(A,I6,I5,E12.4)','*** WARNING  TAU >= MAXIMUM TAUCORE',Map2Global(L).LG,ICORE,TAU(L)
      ENDIF
      NWARNING = NWARNING+1
      IF( (MOD(NWARNING,100) == 0 .OR. NWARNING == 1) .AND. NDM == 1 )THEN  ! *** Can't write to log when running multi-threaded 
        CLOSE(8)
        OPEN(8,FILE=OUTDIR//'EFDCLOG.OUT',POSITION='APPEND')
        WRITE(8,'(A,I6,I5,F10.3,E12.4)')'*** WARNING  TAU >= MAXIMUM TAUCORE:  L,ICORE,TIMEDAY,TAU',Map2Global(L).LG,ICORE,TIMEDAY,TAU(L)
        CLOSE(8)
      ENDIF
      TAUDD(1) = TAULOC(ITBM-1)
      TAUDD(2) = TAULOC(ITBM)
      NTAU0 = ITBM-1
      NTAU1 = ITBM
      
    ELSEIF( TAU(L) < TAULOC(1) )THEN
      IF( NWARNING < 100 )THEN
        PRINT '(A,I6,I5,E12.4)','*** WARNING  TAU < MINIMUM TAUCORE',Map2Global(L).LG,ICORE,TAU(L)
      ENDIF
      NWARNING = NWARNING+1
      IF( (MOD(NWARNING,100) == 0 .OR. NWARNING == 1) .AND. NDM == 1  )THEN  ! *** Can't write to log when running multi-threaded 
        CLOSE(8)
        OPEN(8,FILE=OUTDIR//'EFDCLOG.OUT',POSITION='APPEND')
        WRITE(8,'(A,I6,I5,F10.3,E12.4)')'*** WARNING  TAU < MINIMUM TAUCORE:  L,ICORE,TIMEDAY,TAU',Map2Global(L).LG,ICORE,TIMEDAY,TAU(L)
        CLOSE(8)
      ENDIF
      TAUDD(1) = TAULOC(1)
      TAUDD(2) = TAULOC(2)
      NTAU0 = 1
      NTAU1 = 2
    ELSE
      DO NS=1,ITBM-1
        IF( TAU(L) >= TAULOC(NS) .AND. TAU(L) < TAULOC(NS+1) )THEN
          TAUDD(1) = TAULOC(NS)
          TAUDD(2) = TAULOC(NS+1)
          NTAU0 = NS
          NTAU1 = NS+1
          EXIT
        ENDIF
      ENDDO
    ENDIF
    
    ! *** Interpolate the erosion rates for shear stress and depth.
    ! *** This utilizes normal sedflume data for deeper layers.
    IF( LAYERACTIVE(K,L) == 2 )THEN 
      ! *** Calculate erosion rates of deeper layers (SEDFlume data)
      IF( NSEDFLUME == 1 )THEN
        SN00 = (TAUDD(2)-TAU(L))/(TAUDD(2)-TAUDD(1)) ! *** weighting factor 1 for interpolation
        SN10 = (TAUDD(1)-TAU(L))/(TAUDD(1)-TAUDD(2)) ! *** weighting factor 2
        SN01 = TSED(K,L)/TSED0(K,L)                  ! *** weighting factor 3
        SN11 = (TSED0(K,L)-TSED(K,L))/TSED0(K,L)     ! *** weighting factor 4
        
        IF( K+1 <= KB )THEN  ! *** Modeled erosion rate
          ERATEMOD=( SN00*EXP(SN11*LOG(ERATE(K+1,L,NTAU0))+SN01*LOG(ERATE(K,L,NTAU0))) &
                   + SN10*EXP(SN11*LOG(ERATE(K+1,L,NTAU1))+SN01*LOG(ERATE(K,L,NTAU1))) )*BULKDENS(K,L)*SQRT(ONE/SH_SCALE(L))
        ELSE                 ! *** Do not allow erosion through the bottom layer
          ERATEMOD = ( SN00*EXP(SN11*LOG(1.0E-9)+SN01*LOG(ERATE(K,L,NTAU0))) &
                     + SN10*EXP(SN11*LOG(1.0E-9)+SN01*LOG(ERATE(K,L,NTAU1))) )*BULKDENS(K,L)*SQRT(ONE/SH_SCALE(L))
        ENDIF
      ELSE
       
        IF( TAU(L) > TAUCOR(K,L) )THEN                                               ! *** Check that the applied shear exceeds the critical shear stress for this layer
          ! *** Erosion rate values (cm/s) computed by equation assume shear in Pascals so convert dynes
          SN00 = EA(ICORE,K)*(0.1*TAU(L))**EN(ICORE,K)                               ! *** Erosion rate (cm/s) of the top layer

          IF( K+1 <= KB )THEN
            SN10 = EA(ICORE,K+1)*(0.1*TAU(L))**EN(ICORE,K+1)                         ! *** Erosion rate (cm/s) of the layer below
          ELSE
            SN10 = 0.0                                                               ! *** Modeled erosion rate in limited by bottom
          ENDIF

          SN11 = (TSED0(K,L)-TSED(K,L))/TSED0(K,L)                                   ! *** Mass weighting factor
          ERATEMOD = ((SN10-SN00)*SN11 + SN00)*BULKDENS(K,L)*SQRT(ONE/SH_SCALE(L))   ! *** linear interpolation for remaining mass in current layer    (g/cm2/s)
          ERATEMOD = MIN(ERATEMOD,MAXRATE(ICORE,K))                                  ! *** Limit erosion rate
        ELSE
          ERATEMOD = 0.0
        ENDIF
      ENDIF
    ELSEIF( LAYERACTIVE(K,L) == 1 )THEN
      ! *** For Layers One and Two (the newly deposited sediments)
      ! *** The erosion rate for these layers is determined from 
      ! *** Sedflume experiments and is based on average particle
      ! *** Size (D50AVG) 
      NSCTOT = NSCD(2)-NSCD(1)                                                       ! *** difference in interpolant size class
      D50TMPP = D50AVG(L)-NSCD(1)                                                    ! *** difference from local size class and lower interpolant
      IF( NSEDFLUME == 1 )THEN
        SN00 = (TAUDD(2)-TAU(L))/(TAUDD(2)-TAUDD(1))                                 ! *** weighting factor 1 for interpolation
        SN10 = (TAUDD(1)-TAU(L))/(TAUDD(1)-TAUDD(2))                                 ! *** weigthing factor 2
        SN01 = D50TMPP/NSCTOT                                                        ! *** weighting factor 3
        SN11 = (NSCTOT-D50TMPP)/NSCTOT                                               ! *** weighting factor 4
        ERATEMOD = (SN00*EXP(SN11*LOG(ERATEND(NSC0,NTAU0)) + SN01*LOG(ERATEND(NSC1,NTAU0))) + SN10*EXP(SN11*LOG(ERATEND(NSC0,NTAU1)) +  &   ! *** log-linear interpolation
                             SN01*LOG(ERATEND(NSC1,NTAU1))))*BULKDENS(K,L)*SQRT(1./SH_SCALE(L))
      ELSE
        ! *** Erosion rate values (cm/s) computed by equation assume shear in Pascals so convert dynes
        SN00 = ACTDEPA(NSC0)*(0.1*TAU(L))**ACTDEPN(NSC0)                             ! *** Erosion rate 1 (cm/s)
        SN10 = ACTDEPA(NSC1)*(0.1*TAU(L))**ACTDEPN(NSC1)                             ! *** Erosion rate 2 (cm/s)
        SN11 = D50TMPP/NSCTOT                                                        ! *** Weighting factor 
        ERATEMOD = ((SN10-SN00)*SN11 + SN00)*BULKDENS(K,L)*SQRT(1./SH_SCALE(L))      ! *** linear interpolation around size class (g/cm2/s)
        ERATEMOD = MIN(ERATEMOD,ACTDEPMAX(NSC0))                                     ! *** Limit erosion rate
      ENDIF
    ENDIF

    ! *** Sort out Thicknesses and Erosion Rates
    EBD = ERATEMOD*DTSEDJ                                                            ! *** Maximum mass potentially eroded this time step for this layer (g/cm^2)

    ! *** If the shear stress is less than the critical shear stress for a
    ! *** particular size class, then it is not eroded from the bed.

    ! *** Calculate New sediment mass (TTEMP) of each sediment in Bed (g/cm^2)
    ! *** Conservation of sediment mass, you can only erode as much as is there.
    ! *** ETOT(NS) = Total erosion at this cell of size class NS
    ! *** ETOTO(L) = Total erosion at this cell
    ! *** ELAY(NS) = Erosion from this layer of size class NS
    ! *** ERO      = Total erosion from layer 
    IF( PROP_ERO(L,0) > 0.0 )THEN                                                    ! *** Propwash is active and there are active ships
      ! *** Active ship traffic with erosion
      PSUS(L,1:NSCM) = 1.0                                                           ! *** Set probability of erosion mass into suspension
      !IF( ISPROPWASH == 1 )THEN
        ! *** Include erosion due to ambient currents for all propwash options (2021-11-10)
        WHERE( TAU(L) >= TCRE(1:NSCM) )
          ELAY(1:NSCM) = PERSED(1:NSCM,K,L)*EBD                                      ! *** Compute erosion due to ambient currents
        ELSEWHERE
          ELAY(1:NSCM)  = 0.0
        ENDWHERE
        ELAY(1:NSCM)  = ELAY(1:NSCM) + PROP_ERO(L,1:NSCM)                            ! *** Add propwash induced erosion
      !ELSE
      !  ! *** Minimize erosion due to ambient currents.  Prioritize propwash
      !  ELAY(1:NSCM) = 0.0
      !  DO NS=1,NSCM
      !    IF( PROP_ERO(L,NS) > 0.0 )THEN
      !      ELAY(NS)  = PROP_ERO(L,NS)                                              ! ***  Add propwash induced erosion
      !    ELSE
      !      IF( TAU(L) >= TCRE(NS) )THEN
      !        ELAY(1:NSCM) = PERSED(1:NSCM,K,L)*EBD                                 ! *** No propwash erosion, add erosion due to ambient currents
      !      ENDIF
      !    ENDIF
      !  ENDDO
      !ENDIF
      ETOT(1:NSCM)  = ETOT(1:NSCM) + ELAY(1:NSCM)
      TTEMP(1:NSCM) = PERSED(1:NSCM,K,L)*TSED(K,L) - ELAY(1:NSCM)                    ! *** Remaining mass in layer for each size class
      EBD = SUM(ELAY)                                                                ! *** Updated total mass erosion
    ELSE
      ! *** Standard erosion processing
      WHERE( TAU(L) >= TCRE(1:NSCM) )
        ELAY(1:NSCM)  = PERSED(1:NSCM,K,L)*EBD
        ETOT(1:NSCM)  = ETOT(1:NSCM) + ELAY(1:NSCM)
        TTEMP(1:NSCM) = PERSED(1:NSCM,K,L)*TSED(K,L) - ELAY(1:NSCM)                  ! *** Remaining mass in layer for each size class
      ELSEWHERE
        ETOT(1:NSCM)  = 0.0
        ELAY(1:NSCM)  = 0.0
        TTEMP(1:NSCM) = PERSED(1:NSCM,K,L)*TSED(K,L)
      ENDWHERE
    ENDIF
    
    ! *** Ensure sufficient mass in current layer, otherwise empty the current layer
    ! *** and reduce erosion for next layer
    DO NS=1,NSCM
      if( TTEMP(NS) < 0.0 )then
        ! *** The mass by class is negative, so zero the mass for that class
        TTEMP(NS) = 0.0                                                              ! *** Set unit mass to zero
        ELAY(NS)  = PERSED(NS,K,L)*TSED(K,L)                                         ! *** Only allow available mass to erode
        IF( PROP_ERO(L,0) > 0. )THEN
          ETOT(NS)  = ELAY(NS)                                                     ! *** Reset total erosion to mass available
          IF( ETOT(NS) < 0.0 )THEN
            ! *** Should never trigger this event
            print '(a,f10.4,i8,3i5,f9.5,6e12.4)', 'Bad mass accounting N, L, NS = ', timeday, NITER, L, K, NS, persed(ns,k,l), tsum, PROP_ERO(L,ns), EBD, tsed(k,l), elay(ns), etot(ns)
            ETOT(NS) = 0.0
            ELAY(NS) = 0.0
          ENDIF
        ELSE
          ETOT(NS)  = ETOT(NS) - PERSED(NS,K,L)*EBD + ELAY(NS)                       ! *** Recalculate total erosion
        ENDIF
      ENDIF
      IF( PROP_ERO(L,NS) > 0.0 )THEN
        PROP_ERO(L,NS) = PROP_ERO(L,NS) - ELAY(NS)                                   ! *** Reduce propwash erosion by the amount removed from current layer
        PROP_ERO(L,NS) = MAX(PROP_ERO(L,NS),0.0)
      ENDIF
    ENDDO
    ERO = SUM(ELAY(1:NSCM))                                                          ! *** Actual final total erosion from the layer   (g/cm^2)
    
    ! *** Subtract total erosion from layer unit mass then Calculate new percentages
    TEMP = TSED(K,L) - ERO                                                           ! *** Eroded layer unit mass.  TSED already has deposition added.
                                                                                     
    IF( TEMP < 1e-6 .OR. SUM(TTEMP(:)) == 0. )THEN                                   ! *** If the remaining mass in the layer is negative, set its mass to zero
      TSED(K,L) = 0.0                                                                ! *** This layer has no mass
      LAYERACTIVE(K,L) = 0                                                           ! *** This layer is absent
      PERSED(1:NSCM,K,L) = 0.0                                                       ! *** Zero mass fractions
    ELSE                                                                             
      TSED(K,L) = TEMP                                                               ! *** New layer unit mass (g/cm^2)
      PERSED(1:NSCM,K,L) = TTEMP(1:NSCM)/TSED(K,L)                                   ! *** New mass fractions
    ENDIF                                                                            

  ENDDO   ! ALL_LAYERS                                                               
  ETOTO(L) = SUM(ETOT(1:NSCM))                                                       ! *** Total erosion in cell (g/cm^2)
  ERO = ETOTO(L)
  
  ! *** Add deposition to top layer
  IF( DEP > 0.0 )THEN                                                                  
    ! *** There is deposition, calculate the new layer unit mass and mass fractions
    LAYERACTIVE(1,L) = 1                                                             ! *** Top sediment bed layer exists (because there is deposition)
    TTEMP(1:NSCM) = PERSED(1:NSCM,1,L)*TSED(1,L)                                     ! *** Mass for each size class for bed before deposition
    TSED(1,L) = TSED(1,L) + DEP                                                      ! *** Add the deposited mass to the active layer 1
    
    IF( ICALC_BL > 0 )THEN
      PERSED(1:NSCM,1,L) = ( TTEMP(1:NSCM) + DEPTSS(1:NSCM) + DEPBL(1:NSCM) )/TSED(1,L)  ! *** Bedload possible
    ELSE
      PERSED(1:NSCM,1,L) = ( TTEMP(1:NSCM) + DEPTSS(1:NSCM) )/TSED(1,L)              ! *** No bedload
    ENDIF
  ENDIF

  ! *** DETERMINE TOTAL SEDIMENT FLUX
  IF( ICALC_BL > 0 )THEN
    DO NS=1,NSCM
      TEMP = (ONE-PSUS(L,NS))*ETOT(NS)                      ! *** Calculate erosion into bedload             (g/cm^2)
      EBL(L,NS)   = TEMP*10000.                             ! *** Save erosion into bedload                  (g/m^2)
      DBL(L,NS)   = DEPBL(NS)*10000.                        ! *** Save deposition from bedload               (g/m^2)
      QBLFLUX(L,NS) = TEMP - DEPBL(NS)                      ! *** Flux in/out of bed for bedload             (g/cm^2)
      QBFLUX(NS)    = PSUS(L,NS)*ETOT(NS) - DEPTSS(NS)      ! *** Flux in/out of bed for suspended load      (g/cm^2)
    ENDDO
  ELSE
    QBFLUX(1:NSCM) = ETOT(1:NSCM) - DEPTSS(1:NSCM)          ! *** Net erosion (+) / Deposition (-) from TSS  (g/cm^2)
  ENDIF
  ETOTO(L) = ETOTO(L)/DTSEDJ                                ! *** Total erosion rate (g/cm^2/s)

  ! *** Update sediment variables for use in the remaining EFDC routines
  FORALL(K=1:KB) SEDDIA50(L,K) = SUM(PERSED(1:NSCM,K,L)*D50(1:NSCM))
  HBED(L,1:KB) = 0.01_8*TSED(1:KB,L)/BULKDENS(1:KB,L)                                             ! *** HBED-Bed height (m)  TSED-sediment layer unit mass (g/cm^2)  BULKDENS-Dry Density of Sediment (g/cm^3)

  WDTDZ                = DTSEDJ*HPKI(L,KSZ(L))                                                    ! *** Delta t over Delta z
  SEDF(L,0,1:NSCM)     = QBFLUX(1:NSCM)*10000._8/DTSEDJ                                           ! *** SEDF-Suspended Sediment flux (g/m^2/s), QBFLUX (g/cm^2)
  SED(L,KSZ(L),1:NSCM) = SEDS(L,KSZ(L),1:NSCM) + (SEDF(L,0,1:NSCM)-SEDF(L,KSZ(L),1:NSCM))*WDTDZ   ! *** SED-Suspended sediment concentration (g/m^3)
  
  ! *** Check for negative concentrations
  K = KSZ(L)
  DO NS=1,NSCM
    IF( SED(L,K,NS) < 0. )THEN
      IF( SED(L,K,NS) < -0.001 )THEN
        OPEN(1,FILE=OUTDIR//'NEGSEDSND.OUT',POSITION='APPEND')  
        WRITE(1,"(' Warning: WC  SED < 0: TIME, NS, I, J, K, NEGSED = ',F12.4,4I5,4E13.4)" ) TIMEDAY, NS, Map2Global(L).IG, Map2Global(L).JG, K, SED(L,K,NS)  
        PRINT "(' Warning: WC  SED < 0: TIME, NS, I, J, K, NEGSED = ',F12.4,4I5,4E13.4)", TIMEDAY, NS, Map2Global(L).IG, Map2Global(L).JG, K, SED(L,K,NS)  
        CLOSE(1)
      ENDIF  
      SED(L,K,NS) = 0.0    ! *** Continue with warning
    ENDIF  
  ENDDO
  
  ! *** Set EFDC standard bed mass variables
  SEDBT(L,1:KB)        = TSED(1:KB,L)*10000.                                                      ! *** SEDBT-Total sediment mass (g/m^2) in a layer, TSED-sediment layer unit mass (g/cm^2)
  DO K=1,KB
    SEDB1(L,K,1:NSCM) = SEDB(L,K,1:NSCM)
    SEDB(L,K,1:NSCM)  = SEDBT(L,K)*PERSED(1:NSCM,K,L)                                             ! *** SEDB-Sediment mass (g/m^2) by class in each layer
  ENDDO

  ! *** Update the volumetric flux rates (m/s) for sediment and porewater.
  QSBDTOP(L) = 0.                                                   
  QWBDTOP(L) = 0.     
  IF( ICALC_BL > 0 )THEN
    DO NS=1,NSCM
      SEDFLUX = SEDF(L,0,NS) + ( EBL(L,NS)-DBL(L,NS) )/DTSEDJ                                     ! *** Total sediment flux           (g/m^2/s)
      QSBDTOP(L) = QSBDTOP(L) + SSGI(NS)*SEDFLUX                                                  ! *** Volume of sediment exchange   (m/s)
      QWBDTOP(L) = QWBDTOP(L) + SSGI(NS)*SEDFLUX*VDRBED(L,KBT(L))                                 ! *** Volume of water exchange      (m/s)
    ENDDO
  ELSE
    DO NS=1,NSCM
      QSBDTOP(L) = QSBDTOP(L) + SSGI(NS)*SEDF(L,0,NS)                                             ! *** Volume of sediment exchange   (m/s)
      QWBDTOP(L) = QWBDTOP(L) + SSGI(NS)*SEDF(L,0,NS)*VDRBED(L,KBT(L))                            ! *** Volume of water exchange      (m/s)
    ENDDO
  ENDIF
  
  ! *** Handle layers
  TSUM = HBED(L,1) + HBED(L,2)
  IF( TSUM > 0. )THEN
    ! *** Active and/or Deposition layers exist.  Accumulate active and Deposition layers into one layer
    ! *** and collapse any empty layers between.
    SURFACE = -1
    KBT(L) = KB
    DO K=3,KB
      IF( TSED(K,L) > 0. )THEN   
        SURFACE = K
        KBT(L) = K-1
        HBED(L,KBT(L))        = HBED(L,1)        + HBED(L,2) 
        SEDB(L,KBT(L),1:NSCM) = SEDB(L,1,1:NSCM) + SEDB(L,2,1:NSCM)
        SEDBT(L,KBT(L))       = SEDBT(L,1)       + SEDBT(L,2) 
        EXIT
      ENDIF
    ENDDO
    IF( SURFACE == -1 )THEN
      ! *** All parent and deep layers are missing.  Only Layers 1 and 2 are active
      KBT(L) = KB
      HBED(L,KBT(L))        = HBED(L,1)        + HBED(L,2) 
      SEDB(L,KBT(L),1:NSCM) = SEDB(L,1,1:NSCM) + SEDB(L,2,1:NSCM)
      SEDBT(L,KBT(L))       = SEDBT(L,1)       + SEDBT(L,2) 
    ENDIF
    
    IF( ISTRAN(5) > 0 )THEN
      ! *** TOXB(L,K)   - MG/M2
      ! *** TSED(K,L)   - G/CM2
      ! *** QBFLUX      - G/CM2
      ! *** HBED(L,1:KB) = 0.01*TSED(1:KB,L)/BULKDENS(1:KB,L)
      K1 = MIN(MAX(KBT(L)+1,2),KB)
      TEMP = TSED(K1,L) - INITMASS(K1)
      
      DO NT=1,NTOX
        TOXB1(L,KBT(L),NT) = TOXB(L,KBT(L),NT)    ! *** Required for bedload transport
      ENDDO
    
      ! *** ADJUST TOXB CONCENTRATIONS FOR BED LAYER CHANGES
      IF( SURFACE > -1 .AND. TEMP /= 0. .AND. INITMASS(K1) > 0 )THEN
        TEMP1 = TEMP/INITMASS(K1)
        ! *** ALLOCATE TOXIC MASS BY BED EXCHANGE
        IF( TEMP1 < 0.0 )THEN
          ! *** SEDIMENT HAS BEEN MOVED TO THE ACTIVE/BUFFER LAYERS
          ! *** CALCULATE MASS OF TOXICS EXCHANGED BETWEEN KBT AND KBT+1
          DO NT=1,NTOX
            TEMP2 = TEMP1*TOXB(L,KBT(L)+1,NT)
            TOXB(L,KBT(L),NT)   = TOXB(L,KBT(L),NT)   - TEMP2
            TOXB(L,KBT(L)+1,NT) = TOXB(L,KBT(L)+1,NT) + TEMP2
          ENDDO
        ELSEIF( TEMP > 0. )THEN
          ! *** SEDIMENT HAS BEEN MOVED FROM THE ACTIVE/BUFFER LAYERS
          DO NT=1,NTOX
            TEMP2 = TEMP1*TOXB(L,KBT(L),NT)
            TOXB(L,KBT(L),NT)   = TOXB(L,KBT(L),NT)   - TEMP2
            TOXB(L,KBT(L)+1,NT) = TOXB(L,KBT(L)+1,NT) + TEMP2
          ENDDO
        ENDIF
      ENDIF
      
      IF( SURFOLD > 2 .AND. SURFOLD /= KBT(L) )THEN
        ! *** OLD PARENT LAYER COMPLETELY ERODED.  ADD MASS OF TOXICS FROM SURFOLD TO KBT
        PRINT '(A,I10,F14.6,I6,2I4,3X,3E12.4)','Eroded through Layer:', N, TIMEDAY, Map2Global(L).LG, SURFOLD, KBT(L), TOXB(L,SURFOLD,1), TOXB(L,KBT(L),1), SEDF(L,0,1)
        DO NT=1,NTOX
          TOXB(L,KBT(L),NT)   = TOXB(L,KBT(L),NT) + TOXB(L,SURFOLD,NT)
          TOXB(L,SURFOLD,NT)  = 0.
        ENDDO
        SEDB1(L,KBT(L),1:NSCM) = SEDB1(L,KBT(L),1:NSCM) + SEDB1(L,SURFOLD,1:NSCM)
      ENDIF
    ENDIF
    
    ! *** Zero any layers above KBT
    K1 = MAX(KBT(L)-1,1)
    DO K=K1,1,-1
      HBED(L,K)         = 0.
      SEDB(L,K,1:NSCM)  = 0.
      SEDB1(L,K,1:NSCM) = 0.
      SEDBT(L,K)        = 0.
    ENDDO

    ! *** Optionally use maximum layer thickness
    IF( HBEDMAX > 0.0 )THEN
      ! *** Check if Deposition layer > Max Layer Thickness
      TEMP1 = TACT/BULKDENS(2,L)*0.01                                       ! *** Thickness of active layer (m)
      IF( KBT(L) > 2 .AND. HBED(L,KBT(L)) > HBEDMAX + TEMP1 + 0.01 )THEN    ! *** Exclude the active layer thickness from max thickness
        ! *** The KBT layer is thicker than the max layer thickness and an empty layer exists below
        TEMP = HBEDMAX/HBED(L,KBT(L))         ! *** Ratio of thickness reduction
        K = KBT(L) - 1                        ! *** New KBT after splitting
        K1 = KBT(L)                           ! *** New deep layer after splitting
        
        HBED(L,K)  = HBED(L,K1) - HBEDMAX
        HBED(L,K1) = HBEDMAX
        
        SMASS(1:NSCM) = SEDB(L,K1,1:NSCM)
        SEDB(L,K,1:NSCM)  = SMASS(1:NSCM)*(ONE-TEMP)
        SEDB(L,K1,1:NSCM) = SMASS(1:NSCM) - SEDB(L,K,1:NSCM)
        SEDBT(L,K)  = SUM(SEDB(L,K,1:NSCM))
        SEDBT(L,K1) = SUM(SEDB(L,K1,1:NSCM))
        
        TEMP1 = TSED(1,L) + TSED(2,L)
        TEMP2 = HBEDMAX*100.*BULKDENS(2,L)    ! *** Mass of sediment of HBEDMAX thickness   (g/cm^2)
        IF( (TSED(2,L)-TEMP2) > 0.0 )THEN
          ! *** Deposition layer has sufficient sediment mass          
          PERSED(1:NSCM,K1,L) = PERSED(1:NSCM,2,L)
          TSED(2,L)  = TSED(2,L) - TEMP2
          TSED(K1,L) = TEMP2
          BULKDENS(K1,L) = BULKDENS(2,L)
        ELSE
          ! *** Deposition layer has insufficient sediment mass   
          PERSED(1:NSCM,1,L) = (PERSED(1:NSCM,1,L)*TSED(1,L) + PERSED(1:NSCM,2,L)*(TSED(2,L)))/(TSED(1,L) + TSED(2,L))
          TSED(1,L)  = TEMP1 - TEMP2
          
          PERSED(1:NSCM,K1,L) = PERSED(1:NSCM,1,L) 
          TSED(K1,L) = TEMP2

          PERSED(1:NSCM,2,L) = 0.0
          TSED(2,L) = 0.0
        ENDIF
        
        IF( ISTRAN(5) > 0 )THEN
          DO NT=1,NTOX
            TEMP1 = TOXB(L,K1,NT)
            TOXB(L,K,NT)  = TEMP1*(ONE-TEMP)
            TOXB(L,K1,NT) = TEMP1 - TOXB(L,K,NT)
          ENDDO        
        ENDIF
        
        KBT(L) = K 

        ! *** SET ACTIVE LAYER FLAG
        DO K=1,KB
          IF( TSED(K,L) > 0.0 )THEN
            IF( LAYERACTIVE(K,L) < 2 ) LAYERACTIVE(K,L) = 1            ! *** Preserve in-place sediment layer flag LAYERACTIVE(K,L) = 2
          ELSE
            LAYERACTIVE(K,L) = 0
            TSED(K,L) = 0.0
          ENDIF
        ENDDO
        
      ENDIF
    ENDIF
    
  ENDIF   ! *** End of Active Layer Exchange 

  ! *** Setup chemical processes in the sediment bed
  IF( ISTRAN(5) > 0 )THEN
    IF( ISGWIT > 0. )THEN  
      !K = KBT(L)
      !VOIDCON1 = VDRBED(L,K)                                          ! *** VDRBED(L,K) = PORBED(L,K)/(1.0-PORBED(L,K))
      !HBEDTMP = (1. + VOIDCON1)*HBED(L,K)/(1. + VDRBED(L,K))  
      !HBEDTMP = HBED(L,K)                                              
      !TMPVALO = VDRBED(L,K)*HBED(L,K)/(1. + VDRBED(L,K))  
      !TMPVALN = VOIDCON1*HBEDTMP/(1. + VOIDCON1)  
      !QWBDTOP(L) = DELTI*(TMPVALO-TMPVALN)  
      !HBED(L,K) = HBEDTMP  
      !QWTRBED(L,K) = QWBDTOP(L) + QGW(L)/DXYP(L) 
      !VDRBED(L,K) = VOIDCON1
    
      ! *** Assumes void ratio does not change. (See commented out code above)
      DO K = 0,KBT(L)
        QWTRBED(L,K) = QGW(L)/DXYP(L)                                  ! *** QWTRBED is the seepage velocity in m/s
      ENDDO  
    ENDIF
  ENDIF
  
  ! delme
  !if( l == 1388 )then
  !  if( timeday > 273.6 )then
  !    write(l,'(i10,f15.6,2i5,3f10.5,20e14.6)') niter, timeday, l, NSCM2, hp(l), belv(l), sum(HBED(L,:)), sum(tsed(:,l)), sum(sed(l,1,:)), DEPTSS(1:NSCM2), sum(DEPBL(:)), DEPO(L), ETOTO(L), sum(QBFLUX(:)), BULKDENS(3,L), SUM(DEPTSS(:)), SUM(DEPTSSB(:)), SUM(SMASS(:)), DEP, DTSEDJ    ! delme
  !  endif
  !endif
  
  RETURN
  
END SUBROUTINE SEDZLJ

