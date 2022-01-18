! ----------------------------------------------------------------------
!   This file is a part of EFDC+
!   Website:  https://eemodelingsystem.com/
!   Repository: https://github.com/dsi-llc/EFDC_Plus.git
! ----------------------------------------------------------------------
! Copyright 2021-2022 DSI, LLC
! Distributed under the GNU GPLv2 License.
! ----------------------------------------------------------------------
SUBROUTINE RSURFPLT

  ! **  SUBROUTINE SURFPLT WRITES FILES TO CONTOUR FREE SURFACE
  ! **  ELEVATION

  ! CHANGE RECORD

  USE GLOBAL

  IMPLICIT NONE
  
  INTEGER :: LINES,LEVELS,L
  REAL    :: DBS,TIME,SURFEL
  CHARACTER*80 TITLE
  
  IF( JSRPPH /= 1) GOTO 300
  OPEN(10,FILE=OUTDIR//'RSURFCN.OUT',STATUS='UNKNOWN')
  CLOSE(10,STATUS='DELETE')
  OPEN(10,FILE=OUTDIR//'RSURFCN.OUT',STATUS='UNKNOWN')
  TITLE='INSTANTANEOUS SURFACE ELEVATION CONTOURS'
  LINES=LA-1
  LEVELS=1
  DBS=0.
  WRITE (10,99) TITLE
  WRITE (10,100)LINES,LEVELS
  WRITE (10,250)DBS
  CLOSE(10)
  JSRPPH=0
    300 CONTINUE
  IF( ISDYNSTP == 0 )THEN
    TIME=DT*FLOAT(N)+TCON*TBEGIN
    TIME=TIME/TCON
  ELSE
    TIME=TIMESEC/TCON
  ENDIF
  OPEN(10,FILE=OUTDIR//'RSURFCN.OUT',POSITION='APPEND' &
         ,STATUS='UNKNOWN')
  WRITE (10,100)N,TIME
  DO L=2,LA
    SURFEL=HLPF(L)+BELV(L)
    WRITE(10,200)IL(L),JL(L),DLON(L),DLAT(L),SURFEL
  ENDDO
  CLOSE(10)
     99 FORMAT(A80)
    100 FORMAT(I10,F12.4)
    101 FORMAT(2I10)
    200 FORMAT(2I5,1X,6E14.6)
    250 FORMAT(12E12.4)
  RETURN
END

