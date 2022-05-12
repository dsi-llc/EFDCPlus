! ----------------------------------------------------------------------
!   This file is a part of EFDC+
!   Website:  https://eemodelingsystem.com/
!   Repository: https://github.com/dsi-llc/EFDC_Plus.git
! ----------------------------------------------------------------------
! Copyright 2021-2022 DSI, LLC
! Distributed under the GNU GPLv2 License.
! ----------------------------------------------------------------------
  SUBROUTINE NEGDEP(NOPTIMAL, LDMOPT, QCHANUT, QCHANVT, ISTL_, SUB1, SVB1, NNEGFLG)

  ! ** SUBROUTINE NEGDEP CHECK EXTERNAL SOLUTION FOR NEGATIVE DEPTHS

  ! CHANGE RECORD

  ! CHANGE RECORD
  ! DATE MODIFIED     BY               DESCRIPTION
  !-------------------------------------------------------------------------------------------!
  !    2014-12       Paul M. Craig     Rewrote the NEGDEP function to be always called with
  !                                    a lot more information dumped to the EFDCLOG.OUT file,
  !                                    including the new ice sub-model information

  USE GLOBAL
  USE RESTART_MODULE
  USE EFDCOUT
  Use Mod_Map_Write_EE_Binary

  IMPLICIT NONE

  INTEGER, INTENT(IN)    :: NOPTIMAL,LDMOPT
  INTEGER, INTENT(INOUT) :: NNEGFLG

  REAL,INTENT(IN),DIMENSION(:) :: SUB1(LCM)
  REAL,INTENT(IN),DIMENSION(:) :: SVB1(LCM)

  INTEGER :: INEGFLG, ISTL_, L, NMD, LHOST, IHOST, JHOST, LCHNU, LCHNV, ICHNU, JCHNU, ICHNV, JCHNV, K, ND, LF, LL, LS, LN, LW, LE
  REAL    :: QCHANUT(NCHANM), QCHANVT(NCHANM), SRFCHAN, SRFHOST, SRFCHAN1, SRFHOST1, SURFTMP, DELTD2, HDRY10
  INTEGER, SAVE :: NEEOUT

  IF( NITER < 2 ) NEEOUT = 0
  INEGFLG = 0
  
  ! **  CHECK FOR NEGATIVE DEPTHS
  !$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(ND,LF,LL,L)
  DO ND=1,NOPTIMAL
    LF=2+(ND-1)*LDMOPT
    LL=MIN(LF+LDMOPT-1,LA)
    DO L=LF,LL
      IF( HP(L) <=  0. )THEN
        INEGFLG = 1
        EXIT
      ENDIF
    ENDDO
  ENDDO
  !$OMP END PARALLEL DO

  IF( INEGFLG == 1 )THEN
    ! *** NEGATIVE DEPTHS FOUND, SO RE-SCAN THEN REPORT
    NNEGFLG = NNEGFLG+1

    OPEN(mpi_log_unit,FILE=OUTDIR//mpi_log_file,POSITION='APPEND')

    DO L=2,LA
      IF( HP(L) <= 0.0 )THEN
        LN=LNC(L)
        LS=LSC(L)
        LW=LWC(L)
        LE=LEC(L)
        WRITE(6,1111) TIMEDAY, NITER, ISTL_, Map2Global(L).LG, Map2Global(L).IG, Map2Global(L).JG, process_id
        WRITE (6,6060) Map2Global(L).IG, Map2Global(L).JG, HP(L), H1P(L), H2P(L)
        WRITE (6,6061) Map2Global(L).IG, Map2Global(L).JG, HU(L), H1U(L)
        WRITE (6,6062) Map2Global(L).IG, Map2Global(L).JG, HU(LE), H1U(LE)
        WRITE (6,6063) Map2Global(L).IG, Map2Global(L).JG, HV(L), H1V(L)
        WRITE (6,6064) Map2Global(L).IG, Map2Global(L).JG, HV(LN), H1V(LN)
        WRITE (6,6065) Map2Global(L).IG, Map2Global(L).JG, QSUME(L), QSUM1E(L)
        WRITE (6,6066) Map2Global(L).IG, Map2Global(L).JG, SUB(L), SUB(LE), SVB(L), SVB(LN)
        IF( IEVAP > 0 )THEN
          WRITE (6,6067) Map2Global(L).IG, Map2Global(L).JG,RAINT(L),EVAPT(L)
        ENDIF
        IF( ISICE > 0 )THEN
          WRITE (6,6068) Map2Global(L).IG, Map2Global(L).JG, ICETHICK(L), ICETHICK1(L), TEM(L,KC), TATMT(L), SOLSWRT(L)
        ENDIF

        IF( ISDYNSTP == 0 )THEN
          DELT=DT
          DELTD2=0.5*DT
        ELSE
          DELT=DTDYN
          DELTD2=0.5*DTDYN
        ENDIF

        WRITE(mpi_log_unit,1111) TIMEDAY, NITER, ISTL_, Map2Global(L).LG, Map2Global(L).IG, Map2Global(L).JG, process_id

        ! *** EE7.2 DIAGNOSTICS
        WRITE (mpi_log_unit,'(2X,A14,5I14)')'L  CWESN', Map2Global(L).LG, Map2Global(LW).LG, Map2Global(LE).LG, Map2Global(LS).LG, Map2Global(LN).LG
        WRITE (mpi_log_unit,'(A)')'DEPTHS'
        WRITE (mpi_log_unit,'(2X,A14,5E14.6)')'HP CWESN',  HP(L), HP(LW), HP(LE), HP(LS), HP(LN)
        WRITE (mpi_log_unit,'(2X,A14,5E14.6)')'H1P CWESN', H1P(L), H1P(LW), H1P(LE), H1P(LS), H1P(LN)
        WRITE (mpi_log_unit,'(2X,A14,5E14.6)')'H2P CWESN', H2P(L), H2P(LW), H2P(LE), H2P(LS), H2P(LN)

        WRITE (mpi_log_unit,'(A)')'WATER SURFACE ELEVATIONS'
        WRITE (mpi_log_unit,'(2X,A14,5E14.6)')'WS CWESN',  BELV(L)+HP(L), BELV(LW)+HP(LW), BELV(LE)+HP(LE), BELV(LS)+HP(LS), BELV(LN)+HP(LN)
        WRITE (mpi_log_unit,'(2X,A14,5E14.6)')'WS1 CWESN', BELV(L)+H1P(L),BELV(LW)+H1P(LW),BELV(LE)+H1P(LE),BELV(LS)+H1P(LS),BELV(LN)+H1P(LN)
        WRITE (mpi_log_unit,'(2X,A14,5E14.6)')'WS2 CWESN', BELV(L)+H2P(L),BELV(LW)+H2P(LW),BELV(LE)+H2P(LE),BELV(LS)+H2P(LS),BELV(LN)+H2P(LN)

        WRITE (mpi_log_unit,'(A)')'FACE DEPTHS'
        WRITE (mpi_log_unit,'(2X,A14,4E14.6)')'HU/HV WESN',   HU(L),  HU(LE),  HV(L),  HV(LN)
        WRITE (mpi_log_unit,'(2X,A14,4E14.6)')'H1U/H1V WESN', H1U(L), H1U(LE), H1V(L), H1V(LN)

        WRITE (mpi_log_unit,'(A)')'MASKS'
        WRITE (mpi_log_unit,'(2X,A14,4E14.6)')'SUB WESN',  SUB(L), SUB(LE), SVB(L), SVB(LN)
        WRITE (mpi_log_unit,'(2X,A14,4E14.6)')'SUB1 WESN', SUB1(L),SUB1(LE),SVB1(L),SVB1(LN)
        WRITE (mpi_log_unit,'(2X,A14,4E14.6)')'SUBO WESN', SUBO(L),SUBO(LE),SVBO(L),SVBO(LN)

        WRITE (mpi_log_unit,'(A)')'DEPTH AVERAGE VELOCITIES'
        WRITE (mpi_log_unit,'(2X,A14,4E14.6)')'U/V WESN',     UHDYE(L)/HU(L)/DYU(L),  UHDYE(LE)/HU(LE)/DYU(LE),  VHDXE(L)/HV(L)/DXV(L),  VHDXE(LN)/HV(LN)/DXV(LN)
        WRITE (mpi_log_unit,'(2X,A14,4E14.6)')'U1/V1 WESN',   UHDY1E(L)/H1U(L)/DYU(L),UHDY1E(LE)/H1U(LE)/DYU(LE),VHDX1E(L)/H1V(L)/DXV(L),VHDX1E(LN)/H1V(LN)/DXV(LN)

        WRITE (mpi_log_unit,'(A)')'BOTTOM SHEAR VELOCITIES'
        WRITE (mpi_log_unit,'(2X,A14,4E14.6)')'UV/VU WESN',   UV(L), UV(LE), VU(L), VU(LN)
        WRITE (mpi_log_unit,'(2X,A14,4E14.6)')'U1V/V1U WESN', U1V(L),U1V(LE),V1U(L),V1U(LN)

        WRITE (mpi_log_unit,'(A)')'FLUX TERMS (W/E AND S/N)'
        WRITE (mpi_log_unit,'(2X,A14,4E14.6)')'UHDYE/VHDXE',  UHDYE(L), UHDYE(LE), VHDXE(L), VHDXE(LN)
        WRITE (mpi_log_unit,'(2X,A14,4E14.6)')'UHDY1E/VHDX1E',UHDY1E(L),UHDY1E(LE),VHDX1E(L),VHDX1E(LN)
        WRITE (mpi_log_unit,'(A)')'MOMENTUM TERMS (W/E AND S/N)'
        WRITE (mpi_log_unit,'(2X,A14,4E14.6)')'FUHDYE/FVHDXE',FUHDYE(L),FUHDYE(LE),FVHDXE(L),FVHDXE(LN)
        WRITE (mpi_log_unit,'(A)')'SOURCE/SINK TERMS'
        WRITE (mpi_log_unit,'(2X,A14,4E14.6)')'QSUME/QSUM1E',QSUME(L),QSUM1E(L)

        ! ***                       FUHDYE(L)=UHDYE(L)-DELTD2*SUB(L)*HRUO(L)*HU(L)*(P(L)-P(LW))+SUB(L)*DELT*DXIU(L)*(DXYU(L)*(TSX(L)-RITB1*TBX(L))+FCAXE(L)+FPGXE(L)-SNLT*FXE(L))
        ! ***                                       ***               WEST                            ******                 EAST
        WRITE (mpi_log_unit,'(16X,A)')'     WEST          EAST'
        WRITE (mpi_log_unit,'(2X,A14,4E14.6)')'X P GRADIENT',  SUBO(L)*DELTD2*HRUO(L)*H1U(L)*(P1(LW)-P1(L)),     SUBO(LE)*DELTD2*HRUO(LE)*H1U(LE)*(P1(L)-P1(LE))
        WRITE (mpi_log_unit,'(2X,A14,4E14.6)')'X SHEARS TOT',  SUBO(L)*DELT*DXIU(L)*(DXYU(L)*(TSX(L)-RITB1*TBX(L))+FCAXE(L)+FPGXE(L)-SNLT*FXE(L)), SUBO(LE)*DELT*DXIU(LE)*(DXYU(LE)*(TSX(LE)-RITB1*TBX(LE))+FCAXE(LE)+FPGXE(LE)-SNLT*FXE(LE))
        WRITE (mpi_log_unit,'(2X,A14,4E14.6)')'X SHEARS T/B',  SUBO(L)*DELT*DXIU(L)*(DXYU(L)*(TSX(L)-RITB1*TBX(L))), SUBO(LE)*DELT*DXIU(LE)*(DXYU(LE)*(TSX(LE)-RITB1*TBX(LE)))
        WRITE (mpi_log_unit,'(2X,A14,4E14.6)')'X SHEARS FCAXE',SUBO(L)*DELT*DXIU(L)*FCAXE(L),                        SUBO(LE)*DELT*DXIU(L)*FCAXE(LE)
        WRITE (mpi_log_unit,'(2X,A14,4E14.6)')'X SHEARS FPGXE',SUBO(L)*DELT*DXIU(L)*FPGXE(L),                        SUBO(LE)*DELT*DXIU(L)*FPGXE(LE)
        WRITE (mpi_log_unit,'(2X,A14,4E14.6)')'X SHEARS FXE',  SUBO(L)*DELT*DXIU(L)*SNLT*FXE(L),                     SUBO(LE)*DELT*DXIU(L)*SNLT*FXE(LE)

        ! ***                       FVHDXE(L)=VHDXE(L)-DELTD2*SVB(L)*HRVO(L)*HV(L)*(P(L)-P(LS ))+SVB(L)*DELT*DYIV(L)*(DXYV(L)*(TSY(L)-RITB1*TBY(L))-FCAYE(L)+FPGYE(L)-SNLT*FYE(L))
        ! ***                                       ***               SOUTH                           ******                 NORTH
        WRITE (mpi_log_unit,'(16X,A)')'     SOUTH        NORTH'
        WRITE (mpi_log_unit,'(2X,A14,4E14.6)')'Y P GRADIENT',  SVBO(L)*DELTD2*HRVO(L)*HV(L)*(P1(L)-P1(LS )),         SVBO(LN)*DELTD2*HRVO(LN)*HV(LN)*(P1(LN)-P1(L))
        WRITE (mpi_log_unit,'(2X,A14,4E14.6)')'Y SHEARS TOT',  SVBO(L)*DELT*DYIV(L)*(DXYV(L)*(TSY(L)-RITB1*TBY(L))-FCAYE(L)+FPGYE(L)-SNLT*FYE(L)), SVBO(LN)*DELT*DYIV(LN)*(DXYV(LN)*(TSY(LN)-RITB1*TBY(LN))-FCAYE(LN)+FPGYE(LN)-SNLT*FYE(LN))
        WRITE (mpi_log_unit,'(2X,A14,4E14.6)')'Y SHEARS T/B',  SVBO(L)*DELT*DYIV(L)*(DXYV(L)*(TSY(L)-RITB1*TBY(L))), SVBO(LN)*DELT*DYIV(LN)*(DXYV(LN)*(TSY(LN)-RITB1*TBY(LN)))
        WRITE (mpi_log_unit,'(2X,A14,4E14.6)')'Y SHEARS FCAYE',SVBO(L)*DELT*DYIV(L)*FCAYE(L),                        SVBO(LN)*DELT*DYIV(LN)*FCAYE(LN)
        WRITE (mpi_log_unit,'(2X,A14,4E14.6)')'Y SHEARS FPGYE',SVBO(L)*DELT*DYIV(L)*FPGYE(L),                        SVBO(LN)*DELT*DYIV(LN)*FPGYE(LN)
        WRITE (mpi_log_unit,'(2X,A14,4E14.6)')'Y SHEARS FYE',  SVBO(L)*DELT*DYIV(L)*SNLT*FYE(L),                     SVBO(LN)*DELT*DYIV(LN)*SNLT*FYE(LN)

        !RCX(L)=1./( 1.+DELT*FXVEGE(L) )
        !RCY(L)=1./( 1.+DELT*FYVEGE(L) )
        IF( ISVEG > 0 )THEN
          WRITE (mpi_log_unit,'(/2X,A14,4E14.6)'),'FXVEGE X/Y',FXVEGE(L),FXVEGE(L),FYVEGE(L),FYVEGE(LN)
          WRITE (mpi_log_unit,'( 2X,A14,4E14.6)'),'RCX/RCY', 1./( 1.+DELT*FXVEGE(L) ),1./( 1.+DELT*FYVEGE(L) ),1./( 1.+DELT*FXVEGE(LE) ),1./( 1.+DELT*FYVEGE(LN) )
        ENDIF

        IF( ISICE > 0 )THEN
          WRITE (mpi_log_unit,'(A)')'ICE CONDITIONS'
          WRITE (mpi_log_unit,'(2X,A14,6E14.6)')'TEM,TATM,SOLAR,ICETEMP,FRAZILICE,ICEVOL',TEM(L,KC),TATMT(L),SOLSWRT(L),ICETEMP(L),FRAZILICE(L,KC),ICEVOL(L)
          WRITE (mpi_log_unit,'(A)')'ICE THICKNESS'
          WRITE (mpi_log_unit,'(2X,A14,5E14.6)')'ICE  CWESN',  ICETHICK(L), ICETHICK(LE), ICETHICK(LW), ICETHICK(LS), ICETHICK(LN)
          WRITE (mpi_log_unit,'(2X,A14,5E14.6)')'ICE1 CWESN',  ICETHICK1(L),ICETHICK1(LE),ICETHICK1(LW),ICETHICK1(LS),ICETHICK1(LN)
        ENDIF
      ENDIF
    ENDDO

    IF( ISPPH == 1 )THEN
      WRITE (6,6069) mpi_log_file

      Call Map_Write_EE_Binary
      if( process_id == master_id )THEN
        WRITE(mpi_log_unit,*) 'NEGDEP: WRITING EE LINKAGE',TIMEDAY
        CALL EE_LINKAGE(-1)  
      endif
    
      NEEOUT = NEEOUT + 1
    ENDIF
    
    IF( NEEOUT > 10 )THEN
      STOP ' ABORTING RUN DUE TO TOO MANY NEGATIVE DEPTHS'
    ENDIF

    DO L=2,LA
      IF( HU(L) < 0. .AND. SUBO(L) > 0.5 )THEN
        INEGFLG=2
        LN=LNC(L)
        WRITE(6,1112)
        WRITE (6,6060) Map2Global(L).IG, Map2Global(L).JG, HP(L), H1P(L), H2P(L)
        WRITE (6,6061) Map2Global(L).IG, Map2Global(L).JG, HU(L), H1U(L)
        WRITE (6,6062) Map2Global(L).IG, Map2Global(L).JG, HU(LEC(L)), H1U(LEC(L))
        WRITE (6,6063) Map2Global(L).IG, Map2Global(L).JG, HV(L), H1V(L)
        WRITE (6,6064) Map2Global(L).IG, Map2Global(L).JG, HV(LN), H1V(LN)
        WRITE (6,6065) Map2Global(L).IG, Map2Global(L).JG, QSUME(L), QSUM1E(L)
        
        WRITE(mpi_log_unit,1112)
        WRITE (mpi_log_unit,6060) Map2Global(L).IG, Map2Global(L).JG, HP(L), H1P(L), H2P(L)
        WRITE (mpi_log_unit,6061) Map2Global(L).IG, Map2Global(L).JG, HU(L), H1U(L)
        WRITE (mpi_log_unit,6062) Map2Global(L).IG, Map2Global(L).JG, HU(LEC(L)), H1U(LEC(L))
        WRITE (mpi_log_unit,6063) Map2Global(L).IG, Map2Global(L).JG, HV(L), H1V(L)
        WRITE (mpi_log_unit,6064) Map2Global(L).IG, Map2Global(L).JG, HV(LN), H1V(LN)
        WRITE (mpi_log_unit,6065) Map2Global(L).IG, Map2Global(L).JG, QSUME(L), QSUM1E(L)
      ENDIF
    ENDDO
    DO L=2,LA
      IF( HV(L) < 0. .AND. SVBO(L) > 0.5 )THEN
        INEGFLG=3
        LN=LNC(L)
        WRITE(6,1113)
        WRITE (6,6060) Map2Global(L).IG, Map2Global(L).JG, HP(L), H1P(L), H2P(L)
        WRITE (6,6061) Map2Global(L).IG, Map2Global(L).JG, HU(L), H1U(L)
        WRITE (6,6062) Map2Global(L).IG, Map2Global(L).JG, HU(LEC(L)), H1U(LEC(L))
        WRITE (6,6063) Map2Global(L).IG, Map2Global(L).JG, HV(L), H1V(L)
        WRITE (6,6064) Map2Global(L).IG, Map2Global(L).JG, HV(LN), H1V(LN)
        WRITE (6,6065) Map2Global(L).IG, Map2Global(L).JG, QSUME(L), QSUM1E(L)
        
        WRITE(mpi_log_unit,1113)
        WRITE (mpi_log_unit,6060) Map2Global(L).IG, Map2Global(L).JG, HP(L), H1P(L), H2P(L)
        WRITE (mpi_log_unit,6061) Map2Global(L).IG, Map2Global(L).JG, HU(L), H1U(L)
        WRITE (mpi_log_unit,6062) Map2Global(L).IG, Map2Global(L).JG, HU(LEC(L)), H1U(LEC(L))
        WRITE (mpi_log_unit,6063) Map2Global(L).IG, Map2Global(L).JG, HV(L), H1V(L)
        WRITE (mpi_log_unit,6065) Map2Global(L).IG, Map2Global(L).JG, QSUME(L), QSUM1E(L)
        WRITE (mpi_log_unit,6064) Map2Global(L).IG, Map2Global(L).JG, HV(LN), H1V(LN)
      ENDIF
    ENDDO

    IF( ISNEGH == 2 )THEN
      IF( MDCHH > 0 )THEN
        DO NMD=1,MDCHH
          WRITE(mpi_log_unit,8000)
          LHOST=LMDCHH(NMD)
          IHOST=IL(LHOST)
          JHOST=JL(LHOST)
          LCHNU=LMDCHU(NMD)
          LCHNV=LMDCHV(NMD)

          ! *** X-DIRECTION CHANNEL
          IF( MDCHTYP(NMD) == 1 )THEN
            ICHNU=IL(LCHNU)
            JCHNU=JL(LCHNU)
            SRFCHAN=HP(LCHNU)+BELV(LCHNU)
            SRFHOST=HP(LHOST)+BELV(LHOST)
            SRFCHAN1=H1P(LCHNU)+BELV(LCHNU)
            SRFHOST1=H1P(LHOST)+BELV(LHOST)
            WRITE(mpi_log_unit,8001)N,NMD,MDCHTYP(NMD),ICHNU,JCHNU,ISCDRY(LCHNU),SRFCHAN,HP(LCHNU),P1(LCHNU), H1P(LCHNU)
            WRITE(mpi_log_unit,8002)IHOST,JHOST,ISCDRY(LHOST),SRFHOST,HP(LHOST),P1(LHOST), H1P(LHOST)
            WRITE(mpi_log_unit,8003)QCHANU(NMD),QCHANUT(NMD),CCCCHU(NMD),CCCCHV(NMD)
          ENDIF
          !
          !         Y-DIRECTION CHANNEL
          !
          IF( MDCHTYP(NMD) == 2 )THEN
            ICHNV=IL(LCHNV)
            JCHNV=JL(LCHNV)
            SRFCHAN=HP(LCHNV)+BELV(LCHNV)
            SRFHOST=HP(LHOST)+BELV(LHOST)
            SRFCHAN1=H1P(LCHNV)+BELV(LCHNV)
            SRFHOST1=H1P(LHOST)+BELV(LHOST)
            WRITE(mpi_log_unit,8001)N,NMD,MDCHTYP(NMD),ICHNV,JCHNV,ISCDRY(LCHNV),SRFCHAN,HP(LCHNV),SRFCHAN1,H1P(LCHNV)
            WRITE(mpi_log_unit,8002)IHOST,JHOST,ISCDRY(LHOST),SRFHOST,HP(LHOST),SRFHOST1,H1P(LHOST)
            WRITE(mpi_log_unit,8003)QCHANV(NMD),QCHANVT(NMD),CCCCHU(NMD),CCCCHV(NMD)
          ENDIF
          WRITE(mpi_log_unit,8004)
        ENDDO
      ENDIF

      CALL Restart_Out(1)

      OPEN(1,FILE=OUTDIR//'EQCOEF.OUT',STATUS='UNKNOWN')
      CLOSE(1,STATUS='DELETE')
      OPEN(1,FILE=OUTDIR//'EQCOEF.OUT',POSITION='APPEND',STATUS='UNKNOWN')
      WRITE(1,1001)NITER,ISTL_
      DO L=2,LA
        SURFTMP=GI*P(L)
        WRITE(1,1001) Map2Global(L).IG, Map2Global(L).JG,CCS(L),CCW(L),CCC(L),CCE(L),CCN(L),FPTMP(L),SURFTMP
      ENDDO
      CLOSE(1)
      OPEN(1,FILE=OUTDIR//'EQTERM.OUT',STATUS='UNKNOWN')
      CLOSE(1,STATUS='DELETE')
      OPEN(1,FILE=OUTDIR//'EQTERM.OUT',POSITION='APPEND',STATUS='UNKNOWN')
      WRITE(1,1001)NITER,ISTL_
      DO L=2,LA
        WRITE(1,1001) Map2Global(L).IG, Map2Global(L).JG,SUB(L),SVB(L), HRUO(L), HRVO(L), HU(L), HV(L)
      ENDDO
      CLOSE(1)
      OPEN(1,FILE=OUTDIR//'CFLMAX.OUT')
      CLOSE(1,STATUS='DELETE')
      OPEN(1,FILE=OUTDIR//'CFLMAX.OUT')
      DO L=2,LA
        WRITE(1,1991) Map2Global(L).IG, Map2Global(L).JG,(CFLUUU(L,K),K=1,KC)
        WRITE(1,1992)(CFLVVV(L,K),K=1,KC)
        WRITE(1,1992)(CFLWWW(L,K),K=1,KC)
        WRITE(1,1992)(CFLCAC(L,K),K=1,KC)
      ENDDO
      CLOSE(1)
      STOP
    ENDIF   ! *** ISNEGH=2

    CLOSE(mpi_log_unit)

  ELSE
    ! *** RESET NNEGFLG COUNTER
    NNEGFLG = 0
  ENDIF     ! *** INEGFLG=1

1001 FORMAT(2I5,10(1X,E12.4))
1002 FORMAT(3I4,10(1X,E9.2))
1991 FORMAT(2I5,12F8.3)
1992 FORMAT(10X,12F8.3)
1111 FORMAT(' *************************************************************************************',/, &
            ' *************************************************************************************',/, &
            ' NEG DEPTH AT CELL CENTER: Timeday = ',F14.6,'  N = ',I12,'  ISTL, L, I, J = '4I10,'  Rank = ',I5)
1112 FORMAT(' NEG DEPTH AT WEST FACE')
1113 FORMAT(' NEG DEPTH AT SOUTH FACE')
6060 FORMAT('  NEG DEPTH AT I,J =',2I4,'  HP,H1P,H2P   =',3(2X,E12.4))
6061 FORMAT('  NEG DEPTH AT I,J =',2I4,'  HUW,H1UW     =',2(2X,E12.4))
6062 FORMAT('  NEG DEPTH AT I,J =',2I4,'  HUE,H1UE     =',2(2X,E12.4))
6063 FORMAT('  NEG DEPTH AT I,J =',2I4,'  HVS,H1VS     =',2(2X,E12.4))
6064 FORMAT('  NEG DEPTH AT I,J =',2I4,'  HVN,H1VN     =',2(2X,E12.4))
6065 FORMAT('  NEG DEPTH AT I,J =',2I4,'  QSUME,QSUM1E =',2(2X,E12.4))
6067 FORMAT('  NEG DEPTH AT I,J =',2I4,'  RAIN,EVAP    =',2(2X,E12.4))
6066 FORMAT('  NEG DEPTH AT I,J =',2I4,'  SUB,SVB      =',4F6.1)
6068 FORMAT('  NEG DEPTH AT I,J =',2I4,'  ICETH,ICETH1,TEM,TATM,SOLAR =',2F8.3,2F8.2,F8.1)
6069 FORMAT('  ************************************************************************************',/, &
    '  ***      MORE DETAILS CAN BE FOUND IN THE FILE:  ',A22,'          ***',/, &
    '  ***      THE LATEST MODEL RESULTS HAVE ALSO BEEN SAVED TO THE EE LINKAGE         ***',/, &
    '  ************************************************************************************')
8001 FORMAT(I7,5I5,4E13.4)
8002 FORMAT(17X,3I5,4E13.4)
8003 FORMAT(32X,4E13.4)
8000 FORMAT('    N    NMD  MTYP   I    J  IDRY      P           H           P1           H1')
8004 FORMAT('                                     QCHANU       QCHANUT      CCCCHU       CCCCHV ')

  RETURN

  END

