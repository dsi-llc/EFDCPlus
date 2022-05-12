! ----------------------------------------------------------------------
!   This file is a part of EFDC+
!   Website:  https://eemodelingsystem.com/
!   Repository: https://github.com/dsi-llc/EFDC_Plus.git
! ----------------------------------------------------------------------
! Copyright 2021-2022 DSI, LLC
! Distributed under the GNU GPLv2 License.
! ----------------------------------------------------------------------
SUBROUTINE SMMBE

  !  CONTROL SUBROUTINE (SMMBE) FOR SEDIMENT COMPONENT OF WATER QUALITY MODEL  
  !  ORGINALLY CODED BY K.-Y. PARK THEN OPTIMIZED AND MODIFIED BY J. M. HAMRICK

  !----------------------------------------------------------------------!  
  ! CHANGE RECORD  
  ! DATE MODIFIED     BY               DESCRIPTION
  !----------------------------------------------------------------------!
  ! 2013-03           Paul M. Craig    Restructed to F90, improved structure
  !                                    and added OMP

  USE GLOBAL  
  Use Variables_MPI
  
  IMPLICIT NONE

  INTEGER :: ND, LF, LL, L, I, IZ, M, L1, ISMERR
  REAL    :: SMBST1, RSMSS 
  REAL    :: SMCH4S, SMK1CH4, SMO2JC, SMSOD, CSODSM, RNSODSM, RJNITSM, RJDENSM, AQJH2SSM, AQJCH4SM, GJCH4SM
  REAL    :: SK1NH4SM, A1NH4SM, A2NH4SM, A22NH4SM, B1NH4SM, B2NH4SM 
  REAL    :: SK1NO3SM, A1NO3SM, A2NO3SM, RK2NO3SM, A22NO3SM, B1NO3SM, B2NO3SM
  REAL    :: SK1H2SSM, A1H2SSM, A2H2SSM, A22H2SSM, B1H2SSM, B2H2SSM
  REAL    :: RSM1PO4,RSM2PO4,A11PO4SM,A22PO4SM,A1PO4SM,A2PO4SM,B11PO4SM,B22PO4SM
  REAL    :: TIMTMP, SMDFNA, SMDFPA, SMDFCA
  REAL    :: SMP1PO4, SMFD1PO4, SMFP1PO4, WQTT, SMP1SI, SMFD1SI, SMFP1SI, A1SISM, A2SISM, A11SISM, SMJ2SI, A22SISM
  REAL    :: B11SISM, B22SISM, RSM1SI, RSM2SI
  REAL, EXTERNAL :: ZBRENT

  ! *** FIRST-ORDER DECAY RATE FOR STRESS (/DAY)
  SMBST1 = 1.0 / (1.0 + SMKBST*DTWQ)        ! WQ VARIABLE DT

  ! THE FOLLOWING LOOP IS NEEDED FOR   WQ VARIABLE DT
  IF( ISDYNSTP /= 0 )THEN
    DO I=1,ISMZ
      SMHODT(I) = SMHSED(I)/DTWQ
      SMDTOH(I) = DTWQ/SMHSED(I)
      SMHODT(I) = SMHSED(I)/DTWQ
      SM1DIFT(I) = SMDIFT * SMDTOH(I)/(SMHSED(I)+ 1.E-18)
      SM2DIFT(I) = 1.0 / (1.0 + SM1DIFT(I))
      SMW2DTOH(I) = 1.0 + SMW2(I)*SMDTOH(I)
      SMW2PHODT(I) = SMW2(I) + SMHODT(I)
      SMDPMIN(I) = XSMDPMIN / (SMHSED(I)+ 1.E-18)
    ENDDO
  ENDIF
  
  !$OMP PARALLEL DEFAULT(SHARED) 
  !$OMP DO PRIVATE(ND, LF, LL, L, IZ, M, TIMTMP, SMDFNA, SMDFPA, SMDFCA)  
  DO ND=1,NDM  
    LF=2+(ND-1)*LDM  
    LL=MIN(LF+LDM-1,LA)

    ! *** SED TEMP., & FIND AN INDEX FOR LOOK-UP TABLE FOR TEMPERATURE DEPENDENCY
    DO L=LF,LL
      IZ = ISMZMAP(L)
      SMT(L) = (SMT(L) + SM1DIFT(IZ)*TEM(L,KSZ(L))) * SM2DIFT(IZ)
      ISMT(L)=NINT((SMT(L)-WQTDsMIN)/WQTDsINC)+1  ! *** DSI SINGLE! LINE
      IF( ISMT(L) < 1 .OR. ISMT(L) > NWQTD )THEN
        IF( ISDYNSTP == 0 )THEN
          TIMTMP=(DT*FLOAT(N)+TCON*TBEGIN)/86400.
        ELSE
          TIMTMP=TIMESEC/86400.
        ENDIF
        
        if(process_id == master_id) then
            OPEN(1,FILE=OUTDIR//'ERROR.LOG',POSITION='APPEND' ,STATUS='UNKNOWN')
            WRITE(1,911) TIMTMP, L, IL(L), JL(L), TEM(L,KSZ(L)), SMT(L)
            CLOSE(1)
        end if
        
        PRINT *, 'L, TEM(L,KSZ(L)), SMT(L) = ', Map2Global(L).LG, TEM(L,KSZ(L)), SMT(L)
  
        ! ISMT(L) WAS SET EQUAL TO THE BOUNDS IF IT EXCEEDED THE BOUNDS, THUS
        ! THE MODEL IS NOW ALLOWED TO CONTINUE TO RUN.  THE USER SHOULD CHECK
        ! THE ERROR.LOG FILE FOR SEDIMENT TEMPERATURES OUT OF RANGE.
        !          STOP 'ERROR!! INVALID SEDIMENT TEMPERATURE'
  
        IF( ISMT(L)  <  1) ISMT(L)=1
        IF( ISMT(L)  >  NWQTD) ISMT(L) = NWQTD
      ENDIF
    ENDDO

    ! *** Algal Source Terms
    DO M=1,NSMG
      DO L=LF,LL
        SMDFNA = SMFNBC(M)*WQANCC*WQDFBC(L) + SMFNBD(M)*WQANCD*WQDFBD(L) + SMFNBG(M)*WQANCG*WQDFBG(L)
        SMDFPA = ( SMFPBC(M)*WQDFBC(L) + SMFPBD(M)*WQDFBD(L) + SMFPBG(M)*WQDFBG(L) ) * WQAPC(L)
        SMDFCA = SMFCBC(M)*WQDFBC(L) + SMFCBD(M)*WQDFBD(L) + SMFCBG(M)*WQDFBG(L)              ! *** Alg!al P
          
        SMDFN(L,M) = SMDFNA + SMFNR(ISMZMAP(L),M)*WQDFRN(L)  ! *** RPON
        SMDFP(L,M) = SMDFPA + SMFPR(ISMZMAP(L),M)*WQDFRP(L)  ! *** RPOP
        SMDFC(L,M) = SMDFCA + SMFCR(ISMZMAP(L),M)*WQDFRC(L)  ! *** RPOC
      ENDDO
    ENDDO
    DO L=LF,LL
      SMDFN(L,1) = SMDFN(L,1) + WQDFLN(L)
      SMDFP(L,1) = SMDFP(L,1) + WQDFLP(L)
      SMDFC(L,1) = SMDFC(L,1) + WQDFLC(L)
    ENDDO
  ENDDO  ! *** END OF DOMAIN
  !$OMP END DO
  
  ! *** APPLY OPEN BOUNDARYS
  !OMP SINGLE
  DO L1=1,NBCSOP
    L=LOBCS(L1)
    SMDFN(L,1) = 0.0
    SMDFP(L,1) = 0.0
    SMDFC(L,1) = 0.0
  ENDDO
  !OMP END SINGLE

  !$OMP DO PRIVATE(ND, LF, LL, L, M)        
   DO ND=1,NDM  
    LF=2+(ND-1)*LDM  
    LL=MIN(LF+LDM-1,LA)

    !: SMW2 IN M/D,SMW2DTOH(IZ)=1.0+SMW2*SMDTOH
  
    ! *** ADD SOURCE TERM FROM ALGAE AND THEN ADJUST FOR BURIAL & DECAY
    DO M=1,NSMG
      DO L=LF,LL
        SMPON(L,M)=(SMPON(L,M) + SMDFN(L,M)*SMDTOH(ISMZMAP(L))) / (SMW2DTOH(ISMZMAP(L)) + SMTDND(ISMT(L),M)*DTWQ+ 1.E-18)
        SMPOP(L,M)=(SMPOP(L,M) + SMDFP(L,M)*SMDTOH(ISMZMAP(L))) / (SMW2DTOH(ISMZMAP(L)) + SMTDPD(ISMT(L),M)*DTWQ+ 1.E-18)
        ! ***       Org C         Algal Src
        SMPOC(L,M)=(SMPOC(L,M) + SMDFC(L,M)*SMDTOH(ISMZMAP(L))) / (SMW2DTOH(ISMZMAP(L)) + SMTDCD(ISMT(L),M)*DTWQ+ 1.E-18)
      ENDDO
    ENDDO

    DO L=LF,LL
      SMDGFN(L) = SMHSED(ISMZMAP(L)) * (SMTDND(ISMT(L),1)*SMPON(L,1)+SMTDND(ISMT(L),2)*SMPON(L,2))
      SMDGFP(L) = SMHSED(ISMZMAP(L)) * (SMTDPD(ISMT(L),1)*SMPOP(L,1)+SMTDPD(ISMT(L),2)*SMPOP(L,2))
      SMDGFC(L) = SMHSED(ISMZMAP(L)) * (SMTDCD(ISMT(L),1)*SMPOC(L,1)+SMTDCD(ISMT(L),2)*SMPOC(L,2))
  
      ! COMMON PARAMETERS: SMBST1=1/(1+SMKBST*DTWQ),SM1OKMDP=1/SMKMDP
      !: USE SMTMP(L) TO STORE OLD SMBST(L)
      XSMO20(L) = MAX( WQV(L,KSZ(L),19), 3.0 )
      SMTMP(L) = SMBST(L)
      IF( XSMO20(L) < SMKMDP )THEN
        SMBST(L) =(SMTMP(L) +DTWQ*(1.0-XSMO20(L)*SM1OKMDP)) * SMBST1
      ELSE
        SMBST(L) = SMBST(L)*SMBST1
      ENDIF
    ENDDO
  ENDDO  ! *** END OF DOMAIN
  !$OMP END DO
  
  ! *** APPLY OPEN BOUNDARYS
  !$OMP SINGLE
  DO L1=1,NBCSOP
    L=LOBCS(L1)
    SMDGFN(L) = 0.0
    SMDGFP(L) = 0.0
    SMDGFC(L) = 0.0
    SMTMP(L) = 0.0
    SMBST(L) = 0.0
  ENDDO
  !$OMP END SINGLE

  !$OMP DO PRIVATE(ND, LF, LL, L, IZ)             
  DO ND=1,NDM  
    LF=2+(ND-1)*LDM  
    LL=MIN(LF+LDM-1,LA)

    ! *** BENTHIC MIXING USING HYSTERESIS
    IF( ISMHYST == 1 )THEN
      DO L=LF,LL
        IF( SCB(L) > 0.5 )THEN
          IF( SMHYST(L) )THEN
            !IF(XSMO20(L) >= SMO2BS) ISMHYPD(L) = ISMHYPD(L) - 1    ! WQ VAR DT
            IF( XSMO20(L) >= SMO2BS) SMHYPD(L) = SMHYPD(L) - DTWQ
            IF( SMHYPD(L) <= 0. )THEN
              SMHYST(L) = .FALSE.
              SMHYPD(L) = 0.
            ENDIF
            SMBST(L) = SMTMP(L)
          ELSE
            !IF(XSMO20(L) < SMO2BS) ISMHYPD(L) = ISMHYPD(L) + 1    ! WQ VAR DT
            IF( XSMO20(L) < SMO2BS) SMHYPD(L) = SMHYPD(L) + DTWQ
            IF( SMHYPD(L) >= SMHYDUR )THEN
              SMHYST(L) = .TRUE.
              SMHYPD(L) = SMHYLAG
            ENDIF
          ENDIF
        ENDIF
      ENDDO
      !ENDDO
    ENDIF

    !: SMDPMIN(IZ)=SMDPMIN/SMHSED
    DO L=LF,LL
      IZ = ISMZMAP(L)
      SMW12(L)  = SMDP(IZ)*SMTDDP(ISMT(L)) * SMPOC(L,1) * XSMO20(L) * (1.0-SMKBST*SMBST(L)) / (SMKMDP+XSMO20(L)+ 1.E-18) + SMDPMIN(IZ)
      SMKL12(L) = SMDD(IZ)*SMTDDD(ISMT(L)) + SMRBIBT*SMW12(L)
    ENDDO
  ENDDO  ! *** END OF DOMAIN
  !$OMP END DO
  
  ! *** APPLY OPEN BOUNDARYS
  !$OMP SINGLE
  DO L1=1,NBCSOP
    L=LOBCS(L1)
    SMKL12(L) = 0.0
  ENDDO
  !$OMP END SINGLE

  !$OMP DO PRIVATE(ND, LF, LL, L, IZ, M, ISMERR)              &
  !$OMP    PRIVATE(RSMSS, SMCH4S, SMK1CH4, SMO2JC, SMSOD, CSODSM)  &
  !$OMP    PRIVATE(RNSODSM, RJNITSM, RJDENSM, AQJH2SSM, AQJCH4SM, GJCH4SM)  &
  !$OMP    PRIVATE(SK1NH4SM, A1NH4SM, A2NH4SM,           A22NH4SM, B1NH4SM, B2NH4SM)  &
  !$OMP    PRIVATE(SK1NO3SM, A1NO3SM, A2NO3SM, RK2NO3SM, A22NO3SM, B1NO3SM, B2NO3SM)  &
  !$OMP    PRIVATE(SK1H2SSM, A1H2SSM, A2H2SSM,           A22H2SSM, B1H2SSM, B2H2SSM)  &
  !$OMP    PRIVATE(RSM1PO4,RSM2PO4,A11PO4SM,A22PO4SM,A1PO4SM,A2PO4SM,B11PO4SM,B22PO4SM)  &
  !$OMP    PRIVATE(TIMTMP, SMDFNA, SMDFPA, SMDFCA)  &
  !$OMP    PRIVATE(SMP1PO4, SMFD1PO4, SMFP1PO4, WQTT, SMP1SI, SMFD1SI, SMFP1SI, A1SISM, A2SISM, A11SISM, SMJ2SI, A22SISM)  &
  !$OMP    PRIVATE(B11SISM, B22SISM, RSM1SI, RSM2SI)
  DO ND=1,NDM  
    LF=2+(ND-1)*LDM  
    LL=MIN(LF+LDM-1,LA)

    ! NH4, NO3
    DO L=LF,LL
      IF( SCB(L) > 0.5 )THEN
        IZ = ISMZMAP(L)

        ! *** Ammonia
        SK1NH4SM = ( SMKNH4(IZ)*SMTDNH4(ISMT(L)) * XSMO20(L) ) / ( (SMKMO2N+XSMO20(L)+ 1.E-12) * (SMKMNH4+SM1NH4(L)) )
        A1NH4SM = SMKL12(L)*SMFD1NH4 + SMW12(L)*SMFP1NH4 + SMW2(IZ)
        A2NH4SM = SMKL12(L)*SMFD2NH4 + SMW12(L)*SMFP2NH4
        A22NH4SM = A2NH4SM + SMW2PHODT(IZ)
        B1NH4SM = WQV(L,KSZ(L),14)
        B2NH4SM = SMDGFN(L) + SMHODT(IZ)*SM2NH4(L)
      
        ! *** Nitrate
        SK1NO3SM = SMK1NO3(IZ)*SMTDNO3(ISMT(L))
        A1NO3SM = SMKL12(L) + SMW2(IZ)
        A2NO3SM = SMKL12(L)
        RK2NO3SM = SMK2NO3(IZ)*SMTDNO3(ISMT(L))
        A22NO3SM = A2NO3SM + SMW2PHODT(IZ) + RK2NO3SM
        B1NO3SM = WQV(L,KSZ(L),15)
        B2NO3SM = SMHODT(IZ)*SM2NO3(L)

        ! *** H2S/CH4
        SMO2JC = SMO2C*SMDGFC(L)
        IF( SAL(L,KSZ(L)) > SMCSHSCH )THEN
          ! *** H2S for salinity > SMCSHSCH
          SK1H2SSM = SMK1H2S(ISMT(L)) * XSMO20(L)
          A1H2SSM = SMKL12(L)*SMFD1H2S + SMW12(L)*SMFP1H2S + SMW2(IZ)
          A2H2SSM = SMKL12(L)*SMFD2H2S + SMW12(L)*SMFP2H2S
          A22H2SSM = A2H2SSM + SMW2PHODT(IZ)
          B1H2SSM = 0.0
          B2H2SSM = SMHODT(IZ)*SM2H2S(L)
        ELSE
          ! *** Methane for salinity <= SMCSHSCH
          SMCH4S = (10.0 + HP(L) + SMHSED(IZ)) * SMTD1CH4(ISMT(L)) &
              * SMKL12(L)
          SMK1CH4 = SMTD2CH4(ISMT(L))
        ENDIF

        ! BACK SUBSTITUTION TO GET SMSS
        SMSOD = ZBRENT(L, ISMERR, SMCH4S, SMK1CH4, SMO2JC,                                &
                       SK1NH4SM, A1NH4SM, A2NH4SM,           A22NH4SM, B1NH4SM, B2NH4SM,  &
                       SK1NO3SM, A1NO3SM, A2NO3SM, RK2NO3SM, A22NO3SM, B1NO3SM, B2NO3SM,  &
                       SK1H2SSM, A1H2SSM, A2H2SSM,           A22H2SSM, B1H2SSM, B2H2SSM,  &
                       SM1H2S(L), SM1NH4(L), SM1NO3(L), SM2H2S(L), SM2NH4(L) , SM2NO3(L), &
                       CSODSM, RNSODSM, RJNITSM, RJDENSM, AQJH2SSM, AQJCH4SM, GJCH4SM, RSMSS)

        IF( DEBUG )THEN
          IF( ISMERR == 1 )THEN
              
            if(process_id == master_id) then
                OPEN(1,FILE=OUTDIR//'ZBRENT.LOG',STATUS='UNKNOWN', POSITION='APPEND')
                WRITE(1,401) ITNWQ,L,IL(L),JL(L),SMSOD, ' ROOT MUST BE BRACKETED FOR ZBRENT  '
                CLOSE(1)
            end if
            
          ELSE IF( ISMERR == 2 )THEN
            
              if(process_id == master_id) then
                  OPEN(1,FILE=OUTDIR//'ZBRENT.LOG',STATUS='UNKNOWN', POSITION='APPEND')
                  WRITE(1,401) ITNWQ,L,IL(L),JL(L),SMSOD, ' ZBRENT EXCEEDING MAXIMUM ITERATIONS'
                  CLOSE(1)
              end if
              
          ENDIF
        ENDIF

        SMSS(L)   = RSMSS
        WQBFO2(L) = -SMSOD * SODMULT(IZ)
        SMCSOD(L) = -CSODSM
        SMNSOD(L) = -RNSODSM
        SMJNIT(L) = RJNITSM
        SMJDEN(L) = RJDENSM

        ! *** COD BASED ON     H2S   OR   CH4
        SMJAQH2S(L) =       AQJH2SSM + AQJCH4SM
        SMJGCH4(L) = GJCH4SM
        WQBFNH4(L) = SMSS(L) * (SMFD1NH4*SM1NH4(L) - WQV(L,KSZ(L),14))
        WQBFNO3(L) = SMSS(L) * (SM1NO3(L) - WQV(L,KSZ(L),15))
        WQBFCOD(L) = SMJAQH2S(L) - SMSS(L)*WQV(L,KSZ(L),18)
      ENDIF
    ENDDO

    ! *** PO4
    DO L=LF,LL
      IF( SCB(L) > 0.5 )THEN
        IF( XSMO20(L) < SMCO2PO4 )THEN
          SMP1PO4 = SMP2PO4 * SMDP1PO4(ISMZMAP(L))**(XSMO20(L)/(SMCO2PO4+ 1.E-18))
        ELSE
          SMP1PO4 = SMP2PO4 * SMDP1PO4(ISMZMAP(L))
        ENDIF
        SMFD1PO4 = 1.0 / (1.0 + SMM1*SMP1PO4)
        SMFP1PO4 = 1.0 - SMFD1PO4
        A1PO4SM = SMKL12(L)*SMFD1PO4 + SMW12(L)*SMFP1PO4 + SMW2(ISMZMAP(L))
        A2PO4SM = SMKL12(L)*SMFD2PO4 + SMW12(L)*SMFP2PO4
        A11PO4SM = SMSS(L)*SMFD1PO4 + A1PO4SM
        A22PO4SM = A2PO4SM + SMW2PHODT(ISMZMAP(L))
        B11PO4SM = SMSS(L) * WQPO4D(L,1)
        B22PO4SM = SMDGFP(L) + SMHODT(ISMZMAP(L))*SM2PO4(L)

        CALL SOLVSMBE(RSM1PO4,RSM2PO4,A11PO4SM,A22PO4SM,A1PO4SM,A2PO4SM,B11PO4SM,B22PO4SM)

        SMD1PO4(L) = SMFD1PO4*RSM1PO4
        WQBFPO4D(L) = SMSS(L) * (SMD1PO4(L) - WQPO4D(L,1))
        SM1PO4(L) = RSM1PO4
        SM2PO4(L) = RSM2PO4
      ENDIF
    ENDDO

    ! *** SI
    IF( IWQSI == 1 )THEN
      DO L=LF,LL
        IF( SCB(L) > 0.5 )THEN
          SMDFSI(L) = (WQASCD*WQDFBD(L) + WQDFSI(L) + SMJDSI) * SMDTOH(ISMZMAP(L))
          WQTT = DTWQ * SMTDSI(ISMT(L)) * (SMSISAT-SMFD2SI*SM2SI(L)) / (SMPSI(L)+SMKMPSI+ 1.E-18)
          SMPSI(L) = (SMPSI(L)+SMDFSI(L)) / (SMW2DTOH(ISMZMAP(L))+WQTT+ 1.E-18)
          IF( XSMO20(L) < SMCO2SI )THEN
            SMP1SI = SMP2SI * SMDP1SI**(XSMO20(L)/(SMCO2SI+ 1.E-18))
          ELSE
            SMP1SI = SMP2SI * SMDP1SI
          ENDIF
          SMFD1SI = 1.0 / (1.0 + SMM1*SMP1SI)
          SMFP1SI = 1.0 - SMFD1SI
          A1SISM = SMKL12(L)*SMFD1SI + SMW12(L)*SMFP1SI + SMW2(ISMZMAP(L))
          A2SISM = SMKL12(L)*SMFD2SI + SMW12(L)*SMFP2SI
          A11SISM = SMSS(L)*SMFD1SI + A1SISM
          WQTT = SMTDSI(ISMT(L)) * SMPSI(L) * SMHSED(ISMZMAP(L)) / (SMPSI(L)+SMKMPSI+ 1.E-18)
          SMJ2SI = WQTT * SMSISAT
          A22SISM = A2SISM + SMW2PHODT(ISMZMAP(L)) + WQTT*SMFD2SI
          B11SISM = SMSS(L) * WQSAD(L,1)
          B22SISM = SMHODT(ISMZMAP(L))*SM2SI(L) + SMJ2SI

          CALL SOLVSMBE(RSM1SI,RSM2SI,A11SISM,A22SISM,A1SISM,A2SISM,B11SISM,B22SISM)

          SMD1SI(L) = SMFD1SI*RSM1SI
          WQBFSAD(L) = SMSS(L) * (SMD1SI(L) - WQSAD(L,1))
          SM1SI(L)  = RSM1SI
          SM2SI(L)  = RSM2SI
        ENDIF
      ENDDO
    ENDIF

  ENDDO  ! *** END OF DOMAIN
  !$OMP END DO
  !$OMP END PARALLEL

  IF( ISDYNSTP == 0 )THEN
    TIMTMP=DT*FLOAT(N)+TCON*TBEGIN
    TIMTMP=TIMTMP/TCTMSR
  ELSE
    TIMTMP=TIMESEC/TCTMSR
  ENDIF
  TIMEBF = TIMEBF + TIMTMP

  401 FORMAT(I8,3I5,E12.3,A36)
  911 FORMAT(/,'ERROR: TIME, L, I, J, TEM(L,KSZ(L)), SMT(L) = ', F10.5, 3I4, 2F10.4)

  RETURN

END

