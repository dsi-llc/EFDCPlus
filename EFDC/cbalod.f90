! ----------------------------------------------------------------------
!   This file is a part of EFDC+
!   Website:  https://eemodelingsystem.com/
!   Repository: https://github.com/dsi-llc/EFDC_Plus.git
! ----------------------------------------------------------------------
! Copyright 2021-2022 DSI, LLC
! Distributed under the GNU GPLv2 License.
! ----------------------------------------------------------------------
SUBROUTINE CBALOD1

  ! CHANGE RECORD
  ! **  SUBROUTINES CBALOD CALCULATE GLOBAL VOLUME, MASS, MOMENTUM,
  ! **  AND ENERGY BALANCES

  USE GLOBAL

  IMPLICIT NONE
  
  INTEGER :: L,K,LN

  IF( NBALO > 1) RETURN

  ! **  INITIALIZE VOLUME, SALT MASS, DYE MASS, MOMENTUM, KINETIC ENERGY
  ! **  AND POTENTIAL ENERGY, AND ASSOCIATED FLUXES
  VOLBEGO=0.
  SALBEGO=0.
  DYEBEGO=0.
  UMOBEGO=0.
  VMOBEGO=0.
  UUEBEGO=0.
  VVEBEGO=0.
  PPEBEGO=0.
  BBEBEGO=0.
  VOLOUTO=0.
  SALOUTO=0.
  DYEOUTO=0.
  UMOOUTO=0.
  VMOOUTO=0.
  UUEOUTO=0.
  VVEOUTO=0.
  PPEOUTO=0.
  BBEOUTO=0.
  DO L=2,LA
    LN=LNC(L)
    VOLBEGO=VOLBEGO+SPB(L)*DXYP(L)*H1P(L)
    UMOBEGO=UMOBEGO+SPB(L)*0.5*DXYP(L)*H1P(L)*(DYIU(L)*UHDY1E(L)/H1U(L)+DYIU(LEC(L))*UHDY1E(LEC(L))/H1U(LEC(L)))
    VMOBEGO=VMOBEGO+SPB(L)*0.5*DXYP(L)*H1P(L)*(DXIV(L)*VHDX1E(L)/H1V(L)+DXIV(LN)*VHDX1E(LN)/H1V(LN))
    PPEBEGO=PPEBEGO+SPB(L)*0.5*DXYP(L)*(GI*P1(L)*P1(L)-G*BELV(L)*BELV(L))
  ENDDO
  AMOBEGO=SQRT(UMOBEGO*UMOBEGO+VMOBEGO*VMOBEGO)
  DO K=1,KC
    DO L=2,LA
      LN=LNC(L)
      SALBEGO=SALBEGO+SCB(L)*DXYP(L)*H1P(L)*SAL1(L,K)*DZC(L,K)
      DYEBEGO=DYEBEGO+SCB(L)*DXYP(L)*H1P(L)*DYE1(L,K,1)*DZC(L,K)
      UUEBEGO=UUEBEGO+SPB(L)*0.125*DXYP(L)*H1P(L)*DZC(L,K)*( (U1(L,K)+U1(LEC(L),K))*(U1(L,K)+U1(LEC(L),K)) )
      VVEBEGO=VVEBEGO+SPB(L)*0.125*DXYP(L)*H1P(L)*DZC(L,K)*( (V1(L,K)+V1(LN,K))*(V1(L,K)+V1(LN,K)) )
      BBEBEGO=BBEBEGO+SPB(L)*GP*DXYP(L)*H1P(L)*DZC(L,K)*( BELV(L)+0.5*H1P(L)*(Z(L,K)+Z(L,K-1)) )*B1(L,K)
    ENDDO
  ENDDO
  RETURN
  END

  SUBROUTINE CBALOD2
  !
  ! CHANGE RECORD
  ! **  SUBROUTINES CBALOD CALCULATE GLOBAL VOLUME, MASS, MOMENTUM,
  ! **  AND ENERGY BALANCES
  !
  USE GLOBAL
  IMPLICIT NONE
  INTEGER :: K,LL,L,LN,LS

  ! **  ACCUMULATE FLUXES ACROSS OPEN BOUNDARIES
  !
  DO K=1,KC
    DO LL=1,NCBS
      L=LCBS(LL)
      LN=LNC(L)
      VOLOUTO=VOLOUTO-VHDX2(LN,K)
      SALOUTO=SALOUTO-MIN(VHDX2(LN,K),0.)*SAL1(LN,K)-MAX(VHDX2(LN,K),0.)*SAL1(L,K)
      DYEOUTO=DYEOUTO-MIN(VHDX2(LN,K),0.)*DYE1(LN,K,1)-MAX(VHDX2(LN,K),0.)*DYE1(L,K,1)
      PPEOUTO=PPEOUTO-VHDX2(LN,K)*G*( 0.5*(BELV(L)+BELV(LN))+0.125*(HP(L)+H2P(L)+HP(LN)+H2P(LN))*(Z(L,K)+Z(L,K-1)) )
      BBEOUTO=BBEOUTO-MIN(VHDX2(LN,K),0.)*GP*( BELV(LN)+0.5*HP(LN)*(Z(L,K)+Z(L,K-1)) )*B1(LN,K)-MAX(VHDX2(LN,K),0.)*GP*( BELV(L)+0.5*HP(L)*(Z(L,K)+Z(L,K-1)) )*B1(L,K)
    ENDDO
  ENDDO
  DO K=1,KC
    DO LL=1,NCBW
      L=LCBW(LL)
      VOLOUTO=VOLOUTO-UHDY2(LEC(L),K)
      SALOUTO=SALOUTO-MIN(UHDY2(LEC(L),K),0.)*SAL1(LEC(L),K)-MAX(UHDY2(LEC(L),K),0.)*SAL1(L,K)
      DYEOUTO=DYEOUTO-MIN(UHDY2(LEC(L),K),0.)*DYE1(LEC(L),K,1)-MAX(UHDY2(LEC(L),K),0.)*DYE1(L,K,1)
      PPEOUTO=PPEOUTO-UHDY2(LEC(L),K)*G*(0.5*(BELV(L)+BELV(LEC(L)))+0.125*(HP(L)+H2P(L)+HP(LEC(L))+H2P(LEC(L)))*(Z(L,K)+Z(L,K-1)) )
      BBEOUTO=BBEOUTO-MIN(UHDY2(LEC(L),K),0.)*GP*( BELV(LEC(L))+0.5*HP(LEC(L))*(Z(L,K)+Z(L,K-1)) )*B1(LEC(L),K)-MAX(UHDY2(LEC(L),K),0.)*GP*( BELV(L)+0.5*HP(L)*(Z(L,K)+Z(L,K-1)) )*B1(L,K)
    ENDDO
  ENDDO
  DO K=1,KC
    DO LL=1,NCBE
      L=LCBE(LL)
      VOLOUTO=VOLOUTO+UHDY2(L,K)
      SALOUTO=SALOUTO+MIN(UHDY2(L,K),0.)*SAL1(L,K)+MAX(UHDY2(L,K),0.)*SAL1(LWC(L),K)
      DYEOUTO=DYEOUTO+MIN(UHDY2(L,K),0.)*DYE1(L,K,1)+MAX(UHDY2(L,K),0.)*DYE1(LWC(L),K,1)
      PPEOUTO=PPEOUTO+UHDY2(L,K)*G*( 0.5*(BELV(L)+BELV(LWC(L)))+0.125*(HP(L)+H2P(L)+HP(LWC(L))+H2P(LWC(L)))*(Z(L,K)+Z(L,K-1)) )
      BBEOUTO=BBEOUTO+MIN(UHDY2(L,K),0.)*GP*(BELV(L)+0.5*HP(L)*(Z(L,K)+Z(L,K-1)) )*B1(L,K)+MAX(UHDY2(L,K),0.)*GP*(BELV(LWC(L))+0.5*HP(LWC(L))*(Z(L,K)+Z(L,K-1)) )*B1(LWC(L),K)
    ENDDO
  ENDDO
  DO K=1,KC
    DO LL=1,NCBN
      L=LCBN(LL)
      LS=LSC(L)
      VOLOUTO=VOLOUTO+VHDX2(L,K)
      SALOUTO=SALOUTO+MIN(VHDX2(L,K),0.)*SAL1(L,K)+MAX(VHDX2(L,K),0.)*SAL1(LS,K)
      DYEOUTO=DYEOUTO+MIN(VHDX2(L,K),0.)*DYE1(L,K,1)+MAX(VHDX2(L,K),0.)*DYE1(LS,K,1)
      PPEOUTO=PPEOUTO+VHDX2(L,K)*G*( 0.5*(BELV(L)+BELV(LS))+0.125*(HP(L)+H2P(L)+HP(LS)+H2P(LS))*(Z(L,K)+Z(L,K-1)) )
      BBEOUTO=BBEOUTO+MIN(VHDX2(L,K),0.)*GP*( BELV(L)+0.5*HP(L)*(Z(L,K)+Z(L,K-1)) )*B1(L,K)+MAX(VHDX2(L,K),0.)*GP*( BELV(LS)+0.5*HP(LS)*(Z(L,K)+Z(L,K-1)) )*B1(LS,K)
    ENDDO
  ENDDO
  RETURN
  END

  SUBROUTINE CBALOD3
  !
  ! CHANGE RECORD
  ! **  SUBROUTINES CBALOD CALCULATE GLOBAL VOLUME, MASS, MOMENTUM,
  ! **  AND ENERGY BALANCES
  !
  USE GLOBAL
  IMPLICIT NONE
  INTEGER :: K,LL,L,NS,NCSTMP,NCTL,IU,JU,LU,ID,JD,LD,NWR,KU,KD,NQSTMP
  REAL    :: QWRABS,RQWD
  !
  ! **  ACCUMULATE INTERNAL SOURCES AND SINKS
  !
  DO L=2,LA
    VOLOUTO=VOLOUTO-QSUME(L)
  ENDDO
  DO K=1,KC
    DO LL=1,NQSIJ
      L=LQS(LL)
      PPEOUTO=PPEOUTO-QSS(K,LL)*G*( 0.5*(BELV(L)+BELV(LWC(L)))+0.125*(HP(L)+H2P(L)+HP(LWC(L))+H2P(LWC(L)))*(Z(L,K)+Z(L,K-1)) )
    ENDDO
  ENDDO
  IF( ISTRAN(1) >= 1 )THEN
    DO K=1,KC
      DO L=2,LC
        CONT(L,K)=SAL(L,K)
      ENDDO
    ENDDO
    DO NS=1,NQSIJ
      L=LQS(NS)
      NQSTMP=NQSERQ(NS)
      NCSTMP=NCSERQ(NS,1)
      DO K=1,KC
        SALOUTO=SALOUTO-MAX(QSS(K,NS),0.)*CQS(K,NS,1)-MIN(QSS(K,NS),0.)*SAL(L,K)-MAX(QSERCELL(K,NS),0.)*CSERT(K,NCSTMP,1)-MIN(QSERCELL(K,NS),0.)*SAL(L,K)
      ENDDO
    ENDDO
    DO NCTL=1,NQCTL
      RQWD=1.
      IU=HYD_STR(NCTL).IQCTLU
      JU=HYD_STR(NCTL).JQCTLU
      LU=LIJ(IU,JU)
      ID=HYD_STR(NCTL).IQCTLD
      JD=HYD_STR(NCTL).JQCTLD
      IF( ID == 0 .AND. JD == 0 )THEN
        LD=LC
        RQWD=0.
      ELSE
        LD=LIJ(ID,JD)
      ENDIF
      DO K=1,KC
        SALOUTO=SALOUTO+QCTLT(K,NCTL,1)*CONT(LU,K)-RQWD*QCTLT(K,NCTL,1)*CONT(LU,K)
      ENDDO
    ENDDO
    DO NWR=1,NQWR
      ! *** Handle +/- Flows for Withdrawal/Return Structures
      NQSTMP=WITH_RET(NWR).NQWRSERQ
      IF( QWRSERT(NQSTMP) >= 0. )THEN
        ! *** Original Withdrawal/Return
        IU=WITH_RET(NWR).IQWRU
        JU=WITH_RET(NWR).JQWRU
        KU=WITH_RET(NWR).KQWRU
        ID=WITH_RET(NWR).IQWRD
        JD=WITH_RET(NWR).JQWRD
        KD=WITH_RET(NWR).KQWRD
      ELSE
        ! *** Reverse Flow Withdrawal/Return
        ID=WITH_RET(NWR).IQWRU
        JD=WITH_RET(NWR).JQWRU
        KD=WITH_RET(NWR).KQWRU
        IU=WITH_RET(NWR).IQWRD
        JU=WITH_RET(NWR).JQWRD
        KU=WITH_RET(NWR).KQWRD
        WITH_RET(NWR).QWR=0.  ! *** Only allow time variable flows when using! -W/R
      ENDIF
      QWRABS = ABS(QWRSERT(NQSTMP))
      LU=LIJ(IU,JU)
      LD=LIJ(ID,JD)
      NCSTMP=WITH_RET(NWR).NQWRSERQ

      SALOUTO=SALOUTO+( (WITH_RET(NWR).QWR+QWRABS)*CONT(LU,KU) )
      IF( LD /= 1 .OR. LD /= LC )THEN
        SALOUTO=SALOUTO-( WITH_RET(NWR).QWR*(CONT(LU,KU)+CQWR(NWR,1))+QWRABS*(CONT(LU,KU)+CQWRSERT(NCSTMP,1)) )
      ENDIF
    ENDDO
  ENDIF
  IF( ISTRAN(3) >= 1 )THEN
    DO K=1,KC
      DO L=2,LC
        CONT(L,K)=DYE(L,K,1)
      ENDDO
    ENDDO
    DO NS=1,NQSIJ
      L=LQS(NS)
      NQSTMP=NQSERQ(NS)
      NCSTMP=NCSERQ(NS,1)
      DO K=1,KC
        DYEOUTO=DYEOUTO-MAX(QSS(K,NS),0.)*CQS(K,NS,3)-MIN(QSS(K,NS),0.)*DYE(L,K,1)-MAX(QSERCELL(K,NS),0.)*CSERT(K,NCSTMP,3)-MIN(QSERCELL(K,NS),0.)*DYE(L,K,1)
      ENDDO
    ENDDO
    DO NCTL=1,NQCTL
      RQWD=1.
      IU=HYD_STR(NCTL).IQCTLU
      JU=HYD_STR(NCTL).JQCTLU
      LU=LIJ(IU,JU)
      ID=HYD_STR(NCTL).IQCTLD
      JD=HYD_STR(NCTL).JQCTLD
      IF( ID == 0 .AND. JD == 0 )THEN
        LD=LC
        RQWD=0.
      ELSE
        LD=LIJ(ID,JD)
      ENDIF
      DO K=1,KC
        DYEOUTO=DYEOUTO+QCTLT(K,NCTL,1)*CONT(LU,K)-RQWD*QCTLT(K,NCTL,1)*CONT(LU,K)
      ENDDO
    ENDDO
    DO NWR=1,NQWR
      ! *** Handle +/- Flows for Withdrawal/Return Structures
      NQSTMP=WITH_RET(NWR).NQWRSERQ
      IF( QWRSERT(NQSTMP) >= 0. )THEN
        ! *** Original Withdrawal/Return
        IU=WITH_RET(NWR).IQWRU
        JU=WITH_RET(NWR).JQWRU
        KU=WITH_RET(NWR).KQWRU
        ID=WITH_RET(NWR).IQWRD
        JD=WITH_RET(NWR).JQWRD
        KD=WITH_RET(NWR).KQWRD
      ELSE
        ! *** Reverse Flow Withdrawal/Return
        ID=WITH_RET(NWR).IQWRU
        JD=WITH_RET(NWR).JQWRU
        KD=WITH_RET(NWR).KQWRU
        IU=WITH_RET(NWR).IQWRD
        JU=WITH_RET(NWR).JQWRD
        KU=WITH_RET(NWR).KQWRD
        WITH_RET(NWR).QWR=0.  ! *** Only allow time variable flows when using! -W/R
      ENDIF
      QWRABS = ABS(QWRSERT(NQSTMP))
      LU=LIJ(IU,JU)
      LD=LIJ(ID,JD)
      NCSTMP=WITH_RET(NWR).NQWRSERQ

      DYEOUTO=DYEOUTO+( (WITH_RET(NWR).QWR+QWRABS)*CONT(LU,KU) )
      IF( LD /= 1 .OR. LD /= LC )THEN
        DYEOUTO=DYEOUTO-( WITH_RET(NWR).QWR*(CONT(LU,KU)+CQWR(NWR,3))+QWRABS*(CONT(LU,KU)+CQWRSERT(NCSTMP,3)) )
      ENDIF
    ENDDO
  ENDIF
  RETURN
  END

  SUBROUTINE CBALOD4
  !
  ! CHANGE RECORD
  ! **  SUBROUTINES CBALOD CALCULATE GLOBAL VOLUME, MASS, MOMENTUM,
  ! **  AND ENERGY BALANCES
  !
  USE GLOBAL
  IMPLICIT NONE
  INTEGER :: L,K,LN
  REAL    :: DUTMP,DVTMP
  ! **  CALCULATE MOMENTUM AND ENERGY DISSIPATION
  !
  DO L=2,LA
    LN=LNC(L)
    UUEOUTO=UUEOUTO+0.5*SPB(L)*DXYP(L)*(U(L,KSZ(L))*TBX(L) + U(LEC(L),KSZ(L))*TBX(LEC(L)) - U(L,KC)*TSX(L)-U(LEC(L),KC)*TSX(LEC(L)))
    VVEOUTO=VVEOUTO+0.5*SPB(L)*DXYP(L)*(V(L,KSZ(L))*TBY(L) + V(LN,KSZ(L)) *TBX(LN)  - V(L,KC)*TSY(L)-V(LN,KC)*TSX(LN))
  ENDDO
  DO K=1,KS
    DO L=2,LA
      LN=LNC(L)
      DUTMP=0.5*( U(L,K+1)+U(LEC(L),K+1)-U(L,K)-U(LEC(L),K) )
      DVTMP=0.5*( V(L,K+1)+V(LN,K+1)-V(L,K)-V(LN,K) )
      UUEOUTO=UUEOUTO+SPB(L)*2.0*DXYP(L)*AV(L,K)*( DUTMP*DUTMP )/(DZC(L,K+1)+DZC(L,K))
      VVEOUTO=VVEOUTO+SPB(L)*2.0*DXYP(L)*AV(L,K)*( DVTMP*DVTMP )/(DZC(L,K+1)+DZC(L,K))
      BBEOUTO=BBEOUTO+SCB(L)*DXYP(L)*HP(L)*GP*AB(L,K)*(B(L,K+1)-B(L,K))
    ENDDO
  ENDDO
  RETURN
  END


  SUBROUTINE CBALOD5
  !
  ! CHANGE RECORD
  ! **  SUBROUTINES CBALOD CALCULATE GLOBAL VOLUME, MASS, MOMENTUM,
  ! **  AND ENERGY BALANCES
  !
  USE GLOBAL
  IMPLICIT NONE
  INTEGER :: NTMPD2,L,LN,K
  REAL    :: VOLENDO,SALENDO,DYEENDO,UMOENDO,VMOENDO,UUEENDO,VVEENDO,PPEENDO,BBEENDO,AMOENDO
  REAL    :: ENEBEGO,ENEENDO,ENEOUTO,VOLBMOO,SALBMOO,DYEBMOO,UMOBMOO,VMOBMOO,ENEBMOO
  REAL    :: VOLERR,SALERR,DYEERR,UMOERR
  REAL    :: VMOERR,ENEERR,RSERDE,RDERDE,RUERDE,RVERDE,REERDE,RVERDO,RSERDO,RDERDO,RUERDO,REERDO
  REAL    :: RUMERDE,RVMERDE,RUMERDO,RVMERDO,UUEBMOO,VVEBMOO,PPEBMOO,BBEBMOO

  ! **  CHECK FOR END OF BALANCE PERIOD
  !
  NTMPD2=NTSMMT/2
  IF( NBALO == NTMPD2 )THEN
  !
  ! **  CALCULATE ENDING VOLUME, SALT MASS, DYE MASS, MOMENTUM, KINETIC
  ! **  ENERGY AND POTENTIAL ENERGY, AND ASSOCIATED FLUXES
  !
    VOLENDO=0.
    SALENDO=0.
    DYEENDO=0.
    UMOENDO=0.
    VMOENDO=0.
    UUEENDO=0.
    VVEENDO=0.
    PPEENDO=0.
    BBEENDO=0.
    DO L=2,LA
      LN=LNC(L)
      VOLENDO=VOLENDO+SPB(L)*DXYP(L)*HP(L)
      UMOENDO=UMOENDO+SPB(L)*0.5*DXYP(L)*HP(L)*(DYIU(L)*HUI(L)*UHDYE(L)+DYIU(LEC(L))*HUI(LEC(L))*UHDYE(LEC(L)))
      VMOENDO=VMOENDO+SPB(L)*0.5*DXYP(L)*HP(L)*(DXIV(L)*HVI(L)*VHDXE(L)+DXIV(LN)*HVI(LN)*VHDXE(LN))
      PPEENDO=PPEENDO+SPB(L)*0.5*DXYP(L)*(GI*P(L)*P(L)-G*BELV(L)*BELV(L))
    ENDDO
    AMOENDO=SQRT(UMOENDO*UMOENDO+VMOENDO*VMOENDO)
    DO K=1,KC
      DO L=2,LA
        LN=LNC(L)
        SALENDO=SALENDO+SCB(L)*DXYP(L)*HP(L)*SAL(L,K)*DZC(L,K)
        DYEENDO=DYEENDO+SCB(L)*DXYP(L)*HP(L)*DYE(L,K,1)*DZC(L,K)
        UUEENDO=UUEENDO+SPB(L)*0.125*DXYP(L)*HP(L)*DZC(L,K)*( (U(L,K)+U(LEC(L),K))*(U(L,K)+U(LEC(L),K)) )
        VVEENDO=VVEENDO+SPB(L)*0.125*DXYP(L)*HP(L)*DZC(L,K)*( (V(L,K)+V(LN,K))*(V(L,K)+V(LN,K)) )
        BBEENDO=BBEENDO+SPB(L)*GP*DXYP(L)*HP(L)*DZC(L,K)*( BELV(L)+0.5*HP(L)*(Z(L,K)+Z(L,K-1)) )*B(L,K)
      ENDDO
    ENDDO
    UUEOUTO=DT2*UUEOUTO
    VVEOUTO=DT2*VVEOUTO
    PPEOUTO=DT2*PPEOUTO
    BBEOUTO=DT2*BBEOUTO
    VOLOUTO=DT2*VOLOUTO
    SALOUTO=DT2*SALOUTO
    DYEOUTO=DT2*DYEOUTO
    UMOOUTO=DT2*UMOOUTO
    VMOOUTO=DT2*VMOOUTO
    ENEBEGO=UUEBEGO+VVEBEGO+PPEBEGO+BBEBEGO
    ENEENDO=UUEENDO+VVEENDO+PPEENDO+BBEENDO
    ENEOUTO=UUEOUTO+VVEOUTO+PPEOUTO+BBEOUTO
    VOLBMOO=VOLBEGO-VOLOUTO
    SALBMOO=SALBEGO-SALOUTO
    DYEBMOO=DYEBEGO-DYEOUTO
    UMOBMOO=UMOBEGO-DYEOUTO
    VMOBMOO=VMOBEGO-DYEOUTO
    ENEBMOO=ENEBEGO-ENEOUTO
    VOLERR=VOLENDO-VOLBMOO
    SALERR=SALENDO-SALBMOO
    DYEERR=DYEENDO-DYEBMOO
    UMOERR=UMOENDO-UMOBMOO
    VMOERR=VMOENDO-VMOBMOO
    ENEERR=ENEENDO-ENEBMOO
    RVERDE=-9999.
    RSERDE=-9999.
    RDERDE=-9999.
    RUERDE=-9999.
    RVERDE=-9999.
    REERDE=-9999.
    RVERDO=-9999.
    RSERDO=-9999.
    RDERDO=-9999.
    RUERDO=-9999.
    RVERDO=-9999.
    REERDO=-9999.
    IF( VOLENDO /= 0. ) RVERDE=VOLERR/VOLENDO
    IF( SALENDO /= 0. ) RSERDE=SALERR/SALENDO
    IF( DYEENDO /= 0. ) RDERDE=DYEERR/DYEENDO
    IF( UMOENDO /= 0. ) RUMERDE=UMOERR/UMOENDO
    IF( VMOENDO /= 0. ) RVMERDE=VMOERR/VMOENDO
    IF( ENEENDO /= 0. ) REERDE=ENEERR/ENEENDO
    IF( VOLOUTO /= 0. ) RVERDO=VOLERR/VOLOUTO
    IF( SALOUTO /= 0. ) RSERDO=SALERR/SALOUTO
    IF( DYEOUTO /= 0. ) RDERDO=DYEERR/DYEOUTO
    IF( UMOOUTO /= 0. ) RUMERDO=UMOERR/UMOOUTO
    IF( VMOOUTO /= 0. ) RVMERDO=VMOERR/VMOOUTO
    IF( ENEOUTO /= 0. ) REERDO=ENEERR/ENEOUTO

    ! **  OUTPUT BALANCE RESULTS TO FILE BALO.OUT
    IF( JSBALO == 1 )THEN
      OPEN(89,FILE=OUTDIR//'BALO.OUT',STATUS='UNKNOWN')
      CLOSE(89,STATUS='DELETE')
      OPEN(89,FILE=OUTDIR//'BALO.OUT',STATUS='UNKNOWN')
      JSBALO=0
    ELSE
      OPEN(89,FILE=OUTDIR//'BALO.OUT',POSITION='APPEND',STATUS='UNKNOWN')
    ENDIF
    WRITE(89,890)NTMPD2,N
    WRITE(89,891)
    WRITE(89,892)VOLBEGO,SALBEGO,DYEBEGO,ENEBEGO,UMOBEGO,VMOBEGO,AMOBEGO
    WRITE(89,900)
    WRITE(89,893)
    WRITE(89,892)VOLOUTO,SALOUTO,DYEOUTO,ENEOUTO,UMOOUTO,VMOOUTO
    WRITE(89,900)
    WRITE(89,894)
    WRITE(89,892)VOLBMOO,SALBMOO,DYEBMOO,ENEBMOO,UMOBMOO,VMOBMOO
    WRITE(89,900)
    WRITE(89,895)
    WRITE(89,892)VOLENDO,SALENDO,DYEENDO,ENEENDO,UMOENDO,VMOENDO,AMOENDO
    WRITE(89,900)
    WRITE(89,896)
    WRITE(89,892)VOLERR,SALERR,DYEERR,ENEERR,UMOERR,VMOERR
    WRITE(89,900)
    WRITE(89,897)
    WRITE(89,892)RVERDE,RSERDE,RDERDE,REERDE,RUMERDE,RVMERDE
    WRITE(89,900)
    WRITE(89,898)
    WRITE(89,892)RVERDO,RSERDO,RDERDO,REERDO,RUMERDO,RVMERDO
    WRITE(89,899)
    UUEBMOO=UUEBEGO-UUEOUTO
    VVEBMOO=VVEBEGO-VVEOUTO
    PPEBMOO=PPEBEGO-PPEOUTO
    BBEBMOO=BBEBEGO-BBEOUTO
    WRITE(89,901)UUEBEGO
    WRITE(89,902)UUEOUTO
    WRITE(89,903)UUEBMOO
    WRITE(89,904)UUEENDO
    WRITE(89,900)
    WRITE(89,905)VVEBEGO
    WRITE(89,906)VVEOUTO
    WRITE(89,907)VVEBMOO
    WRITE(89,908)VVEENDO
    WRITE(89,900)
    WRITE(89,909)PPEBEGO
    WRITE(89,910)PPEOUTO
    WRITE(89,911)PPEBMOO
    WRITE(89,912)PPEENDO
    WRITE(89,900)
    WRITE(89,913)BBEBEGO
    WRITE(89,914)BBEOUTO
    WRITE(89,915)BBEBMOO
    WRITE(89,916)BBEENDO
    WRITE(89,900)
    WRITE(89,899)
    CLOSE(89)
    890 FORMAT (' VOLUME, MASS, AND ENERGY BALANCE OVER',I5,' TIME STEPS',' ENDING AT TIME STEP',I5,//)
    891 FORMAT (' INITIAL VOLUME    INITIAL SALT    INITIAL DYE     INITIAL ENER    INITIAL UMO     INITIAL VMO     INITIAL AMO',/)
    892 FORMAT (1X,7(E14.6,2X))
    893 FORMAT (' VOLUME OUT        SALT OUT        DYE OUT         ENERGY OUT      UMO OUT         VMO OUT',/)
    894 FORMAT (' INITIAL-OUT VOL   INIT-OUT SALT   INIT-OUT DYE    INIT-OUT ENER   INIT-OUT UMO    INIT-OUT VMO',/)
    895 FORMAT (' FINAL VOLUME      FINAL SALT      FINAL DYE       FINAL ENERGY    FINAL UMO       FINAL VMO       FINAL AMO',/)
    896 FORMAT (' VOLUME ERR        SALT ERR        DYE ERR         ENERGY ERR      UMO ERR         VMO ERR',/)
    897 FORMAT (' R VOL/END ER      R SAL/END ER    R DYE/END ER    R ENE/END ER    R UMO/END ER    R VMO/END ER',/)
    898 FORMAT (' R VOL/OUT ER      R SAL/OUT ER    R DYE/OUT ER    R ENE/OUT ER    R UMO/OUT ER    R VMO/OUT ER',/)
    899 FORMAT (////)
    900 FORMAT (//)
    901 FORMAT(' UUEBEGO =  ',E14.6)
    902 FORMAT(' UUEOUTO =  ',E14.6)
    903 FORMAT(' UUEBMOO =  ',E14.6)
    904 FORMAT(' UUEENDO =  ',E14.6)
    905 FORMAT(' VVEBEGO =  ',E14.6)
    906 FORMAT(' VVEOUTO =  ',E14.6)
    907 FORMAT(' VVEBMOO =  ',E14.6)
    908 FORMAT(' VVEENDO =  ',E14.6)
    909 FORMAT(' PPEBEGO =  ',E14.6)
    910 FORMAT(' PPEOUTO =  ',E14.6)
    911 FORMAT(' PPEBMOO =  ',E14.6)
    912 FORMAT(' PPEENDO =  ',E14.6)
    913 FORMAT(' BBEBEGO =  ',E14.6)
    914 FORMAT(' BBEOUTO =  ',E14.6)
    915 FORMAT(' BBEBMOO =  ',E14.6)
    916 FORMAT(' BBEENDO =  ',E14.6)
    NBALO=0
  ENDIF
  NBALO=NBALO+1
  RETURN
END

