! ----------------------------------------------------------------------
!   This file is a part of EFDC+
!   Website:  https://eemodelingsystem.com/
!   Repository: https://github.com/dsi-llc/EFDC_Plus.git
! ----------------------------------------------------------------------
! Copyright 2021-2022 DSI, LLC
! Distributed under the GNU GPLv2 License.
! ----------------------------------------------------------------------
  !---------------------------------------------------------------------------!
  !                     EFDC+ Developed by DSI, LLC.
  !---------------------------------------------------------------------------!
  ! @details Remaps the concentration boundary conditions to local values
  ! @author Zander Mausolff, adapted from O'Donncha's code
  ! @date 9/4/2019
  !---------------------------------------------------------------------------!

  Subroutine Map_OpenBC_Conc

  Use GLOBAL
  Use Variables_MPI
  Use Variables_MPI_Mapping
  Use Variables_MPI_Write_Out

  Implicit None

  ! *** Local Variables
  Integer :: II, LL, III, JJJ, MS, K, M, NOPEN
  Integer :: MMAX, MMIN
  Integer :: NCBS_GL, NCBW_GL, NCBE_GL, NCBN_GL
  Integer, ALLOCATABLE, DIMENSION(:) :: LLSave

  NOPEN = NCBW+NCBE+NCBS+NCBN
  ALLOCATE(LLSave(NOPEN))
  LLSave = 0
  
  Call WriteBreak(mpi_mapping_unit)
  write(mpi_mapping_unit,'(a)') 'NUMBER OF CONCENTRATION BOUNDARY CONDITIONS CELLS ON OPEN BOUNDARIES'
  write(mpi_mapping_unit, '(a,I5)') 'Global NCBW = ',  NCBW
  write(mpi_mapping_unit, '(a,I5)') 'Global NCBE = ',  NCBE
  write(mpi_mapping_unit, '(a,I5)') 'Global NCBN = ',  NCBN
  write(mpi_mapping_unit, '(a,I5)') 'Global NCBS = ',  NCBS

  NCBS_GL = NCBS
  NCBS = 0
  II   = 0
  DO LL = 1,NCBS_GL
    III = IG2IL(ICBS_GL(LL))  ! Get local I value
    JJJ = JG2JL(JCBS_GL(LL))  ! Get local J value
    IF(  III > 0 .AND. III <= IC )THEN
      IF(  JJJ > 0 .AND. JJJ <= JC )THEN
        II = II + 1
        LLSave(II) = LL

        NCBS = NCBS + 1
        ICBS(II) = III
        JCBS(II) = JJJ

        NTSCRS(II)   = NTSCRS_GL(LL)
        NCSERS(II,1) = NCSERS_GL(LL,1)
        NCSERS(II,2) = NCSERS_GL(LL,2)
        NCSERS(II,3) = NCSERS_GL(LL,3)
        NCSERS(II,4) = NCSERS_GL(LL,4)
        NCSERS(II,5) = NCSERS_GL(LL,5)
        NCSERS(II,6) = NCSERS_GL(LL,6)
        NCSERS(II,7) = NCSERS_GL(LL,7)
        
        MMAX = 3 + NDYM + NTOX  ! New format (multiple dye classes)
        DO MS = 1,MMAX
          CBS(II,1,MS) = CBS_GL(LL,1,MS)
          CBS(II,2,MS) = CBS_GL(LL,2,MS)
        END DO

        MMIN = MMAX + 1
        MMAX = MMAX + NSED + NSND
        DO MS = MMIN,MMAX
          CBS(II,1,MS) = CBS_GL(LL,1,MS)
          CBS(II,2,MS) = CBS_GL(LL,2,MS)
        END DO
        
      END IF
    END IF
  END DO

  write(mpi_mapping_unit,'(A)') ' '
  write(mpi_mapping_unit,'( 50("*"),A10,47("*") )' )  '  SOUTH  '
  write(mpi_mapping_unit,'(2( " ****",2("********"),a8,3("********"),"|") )' ) 'GLOBAL ', 'LOCAL '
  write(mpi_mapping_unit,'(2(a5,6a8,1x))') 'N','IOPEN','JOPEN','PSER','SAL-BOT','SAL-TOP','SAL-SER','N','IOPEN','JOPEN','PSER','SAL-BOT','SAL-TOP','SAL-SER'
  DO II = 1,NCBS
    LL = LLSave(II)
    write(mpi_mapping_unit,'(2(I5,3I8,2F8.1,I8,1X))') LL,ICBS_GL(LL),JCBS_GL(LL),NPSERS_GL(LL),CBS_GL(LL,1,2),CBS_GL(LL,2,2),NCSERS_GL(LL,2),  &
                                                       II,ICBS(II),   JCBS(II),   NPSERS(II),   CBS(II,1,2)   ,CBS(II,2,2),   NCSERS(II,2)
  ENDDO

  NCBW_GL = NCBW
  NCBW = 0
  II = 0
  DO LL =1,NCBW_GL
    III = IG2IL(ICBW_GL(LL))
    JJJ = JG2JL(JCBW_GL(LL))
    IF(  III .GT. 0 .AND. III <= IC )THEN
      IF(  JJJ .GT. 0 .AND. JJJ <= JC )THEN
        II = II +1
        LLSave(II) = LL

        NCBW = NCBW + 1
        ICBW(II) = III
        JCBW(II) = JJJ
        NTSCRW(II)   = NTSCRW_GL(LL)

        NCSERW(II,1) = NCSERW_GL(LL,1)
        NCSERW(II,2) = NCSERW_GL(LL,2)
        NCSERW(II,3) = NCSERW_GL(LL,3)
        NCSERW(II,4) = NCSERW_GL(LL,4)
        NCSERW(II,5) = NCSERW_GL(LL,5)
        NCSERW(II,6) = NCSERW_GL(LL,6)
        NCSERW(II,7) = NCSERW_GL(LL,7)

        MMAX = 3 + NDYM + NTOX  ! New format (multiple dye classes)
        DO MS = 1,MMAX
          CBW(II,1,MS) = CBW_GL(LL,1,MS)
          CBW(II,2,MS) = CBW_GL(LL,2,MS)
        END DO

        MMIN = MMAX + 1
        MMAX = MMAX+NSED+NSND
        DO MS = MMIN,MMAX
          CBW(II,1,MS) = CBW_GL(LL,1,MS)
          CBW(II,2,MS) = CBW_GL(LL,2,MS)
        END DO
        
      END IF
    END IF
  END DO

  write(mpi_mapping_unit,'(A)') ' '
  write(mpi_mapping_unit,'( 50("*"),A10,47("*") )' )  '   WEST  '
  write(mpi_mapping_unit,'(2( " ****",2("********"),a8,3("********"),"|") )' ) 'GLOBAL ', 'LOCAL '
  write(mpi_mapping_unit,'(2(a5,6a8,1x))') 'N','IOPEN','JOPEN','PSER','SAL-BOT','SAL-TOP','SAL-SER','N','IOPEN','JOPEN','PSER','SAL-BOT','SAL-TOP','SAL-SER'
  DO II = 1,NCBW
    LL = LLSave(II)
    write(mpi_mapping_unit,'(2(I5,3I8,2F8.1,I8,1X))') LL,ICBW_GL(LL),JCBW_GL(LL),NPSERW_GL(LL),CBW_GL(LL,1,2),CBW_GL(LL,2,2),NCSERW_GL(LL,2),  &
                                                       II,ICBW(II),   JCBW(II),   NPSERW(II),   CBW(II,1,2)   ,CBW(II,2,2),   NCSERW(II,2)
  ENDDO

  ! *** East
  NCBE_GL = NCBE ! Set global copy
  NCBE = 0  ! recalculate the local value in the next lines of code
  II = 0
  DO LL =1,NCBE_GL
    III = IG2IL(ICBE_GL(LL))
    JJJ = JG2JL(JCBE_GL(LL))
    IF(  III .GT. 0 .AND. III <= IC )THEN
      IF(  JJJ .GT. 0 .AND. JJJ <= JC )THEN
        II = II + 1
        LLSave(II) = LL

        NCBE = NCBE + 1
        ICBE(II) = III
        JCBE(II) = JJJ
        NTSCRE(II)   = NTSCRE_GL(LL)

        NCSERE(II,1) = NCSERE_GL(LL,1)
        NCSERE(II,2) = NCSERE_GL(LL,2)
        NCSERE(II,3) = NCSERE_GL(LL,3)
        NCSERE(II,4) = NCSERE_GL(LL,4)
        NCSERE(II,5) = NCSERE_GL(LL,5)
        NCSERE(II,6) = NCSERE_GL(LL,6)
        NCSERE(II,7) = NCSERE_GL(LL,7)

        MMAX = 3 + NDYM + NTOX  ! New format (multiple dye classes)
        DO MS = 1,MMAX
          CBE(II,1,MS) = CBE_GL(LL,1,MS)
          CBE(II,2,MS) = CBE_GL(LL,2,MS)
        END DO
        
        MMIN = MMAX + 1
        MMAX = MMAX+NSED+NSND
        DO MS = MMIN,MMAX
          CBE(II,1,MS) = CBE_GL(LL,1,MS)
          CBE(II,2,MS) = CBE_GL(LL,2,MS)
        END DO
        
      END IF
    END IF
  END DO

  write(mpi_mapping_unit,'(A)') ' '
  write(mpi_mapping_unit,'( 50("*"),A10,47("*") )' )  '   EAST  '
  write(mpi_mapping_unit,'(2( " ****",2("********"),a8,3("********"),"|") )' ) 'GLOBAL ', 'LOCAL '
  write(mpi_mapping_unit,'(2(a5,6a8,1x))') 'N','IOPEN','JOPEN','PSER','SAL-BOT','SAL-TOP','SAL-SER','N','IOPEN','JOPEN','PSER','SAL-BOT','SAL-TOP','SAL-SER'
  DO II = 1,NCBE
    LL = LLSave(II)
    write(mpi_mapping_unit,'(2(I5,3I8,2F8.1,I8,1X))') LL,ICBE_GL(LL),JCBE_GL(LL),NPSERE_GL(LL),CBE_GL(LL,1,2),CBE_GL(LL,2,2),NCSERE_GL(LL,2),  &
                                                       II,ICBE(II),   JCBE(II),   NPSERE(II),   CBE(II,1,2)   ,CBE(II,2,2),   NCSERE(II,2)
  ENDDO
  
  ! *** North boundary
  NCBN_GL = NCBN
  NCBN = 0
  II = 0
  DO LL =1,NCBN_GL
    III = IG2IL(ICBN_GL(LL))
    JJJ = JG2JL(JCBN_GL(LL))
    IF(  III .GT. 0 .AND. III <= IC )THEN
      IF(  JJJ .GT. 0 .AND. JJJ <= JC )THEN
        II = II +1
        LLSave(II) = LL
        
        NCBN = NCBN + 1
        ICBN(II) = III
        JCBN(II) = JJJ

        NTSCRN(II)   = NTSCRN_GL(LL)
        NCSERN(II,1) = NCSERN_GL(LL,1)
        NCSERN(II,2) = NCSERN_GL(LL,2)
        NCSERN(II,3) = NCSERN_GL(LL,3)
        NCSERN(II,4) = NCSERN_GL(LL,4)
        NCSERN(II,5) = NCSERN_GL(LL,5)
        NCSERN(II,6) = NCSERN_GL(LL,6)
        NCSERN(II,7) = NCSERN_GL(LL,7)

        MMAX = 3 + NDYM + NTOX  ! New format (multiple dye classes)
        DO MS = 1,MMAX
          CBN(II,1,MS) = CBN_GL(LL,1,MS)
          CBN(II,2,MS) = CBN_GL(LL,2,MS)
        END DO
        
        MMIN = MMAX + 1
        MMAX = MMAX+NSED+NSND
        DO MS = MMIN,MMAX
          CBN(II,1,MS) = CBN_GL(LL,1,MS)
          CBN(II,2,MS) = CBN_GL(LL,2,MS)
        END DO

      END IF
    END IF
  END DO

  write(mpi_mapping_unit,'(A)') ' '
  write(mpi_mapping_unit,'( 50("*"),A10,47("*") )' )  '  NORTH  '
  write(mpi_mapping_unit,'(2( " ****",2("********"),a8,3("********"),"|") )' ) 'GLOBAL ', 'LOCAL '
  write(mpi_mapping_unit,'(2(a5,6a8,1x))') 'N','IOPEN','JOPEN','PSER','SAL-BOT','SAL-TOP','SAL-SER','N','IOPEN','JOPEN','PSER','SAL-BOT','SAL-TOP','SAL-SER'
  DO II = 1,NCBN
    LL = LLSave(II)
    write(mpi_mapping_unit,'(2(I5,3I8,2F8.1,I8,1X))') LL,ICBN_GL(LL),JCBN_GL(LL),NPSERN_GL(LL),CBN_GL(LL,1,2),CBN_GL(LL,2,2),NCSERN_GL(LL,2),  &
                                                       II,ICBN(II),   JCBN(II),   NPSERN(II),   CBN(II,1,2)   ,CBN(II,2,2),   NCSERN(II,2)
  ENDDO

  Call WriteBreak(mpi_mapping_unit)
  
  write(mpi_mapping_unit, '(a,I5)') ' '
  write(mpi_mapping_unit, '(a,I5)') 'Local NCBW  = ',  NCBW
  write(mpi_mapping_unit, '(a,I5)') 'Local NCBE  = ',  NCBE
  write(mpi_mapping_unit, '(a,I5)') 'Local NCBN  = ',  NCBN
  write(mpi_mapping_unit, '(a,I5)') 'Local NCBS  = ',  NCBS

  RETURN

End Subroutine Map_OpenBC_Conc

!---------------------------------------------------------------------------!
!                     EFDC+ Developed by DSI, LLC.
!---------------------------------------------------------------------------!
! @details Remaps the water quality boundary conditions to local values
! @date 2020-03-13
!---------------------------------------------------------------------------!

Subroutine Map_OpenBC_Eutrophication

  Use GLOBAL
  Use Variables_WQ

  Use Variables_MPI
  Use Variables_MPI_Mapping
  Use Variables_MPI_Write_Out

  Implicit None

  ! *** Local Variables
  Integer :: II, LL, III, JJJ, MS, K, M, NOPEN, NT, NW
  Integer :: MMAX, MMIN
  Integer :: NCBS_GL, NCBW_GL, NCBE_GL, NCBN_GL
  Integer, ALLOCATABLE, DIMENSION(:) :: LLSave

  Integer, ALLOCATABLE, DIMENSION(:) :: ITMP
  Integer, ALLOCATABLE, DIMENSION(:) :: JTMP

  NOPEN = NWQOBW + NWQOBE + NWQOBS + NWQOBN
  ALLOCATE(LLSave(NOPEN))
  LLSave = 0
  
  Call WriteBreak(mpi_mapping_unit)
  write(mpi_mapping_unit,'(a)') 'NUMBER OF WQ CONCENTRATION BOUNDARY CONDITIONS CELLS ON OPEN BOUNDARIES'
  write(mpi_mapping_unit, '(a,I5)') 'Global NWQOBW = ',  NWQOBW
  write(mpi_mapping_unit, '(a,I5)') 'Global NWQOBE = ',  NWQOBE
  write(mpi_mapping_unit, '(a,I5)') 'Global NWQOBN = ',  NWQOBN
  write(mpi_mapping_unit, '(a,I5)') 'Global NWQOBS = ',  NWQOBS

  ! *** South
  NCBS_GL = NWQOBS
  ALLOCATE(ITMP(NWQOBS), JTMP(NWQOBS))
  ITMP = IWQCBS
  JTMP = JWQCBS
  
  NWQOBS = 0
  IWQCBS = 0
  JWQCBS = 0
  II   = 0
  DO LL = 1,NCBS_GL
    III = IG2IL(ITMP(LL))  ! Get local I value
    JJJ = JG2JL(JTMP(LL))  ! Get local J value
    IF(  III > 0 .AND. III <= IC )THEN
      IF(  JJJ > 0 .AND. JJJ <= JC )THEN
        II = II + 1
        LLSave(II) = LL

        NWQOBS = NWQOBS + 1
        IWQCBS(II) = III
        JWQCBS(II) = JJJ

        ! *** CONCENTRATION SERIES ASSIGNMENTS
        IF( IWQCBS(II) == IG2IL(ICBS_GL(LL)) .AND. JWQCBS(II) == JG2JL(JCBS_GL(LL)) )THEN
          NCSERS(II,8) = IWQOBS(LL,IDOX)   ! *** ALL CONSTITUENTS USE THE SAME SERIES
        ELSE
          CALL STOPP('WQ: SOUTH OBC: MISS MATCH BETWEEN NCBS & NWQOBS')
        ENDIF
        
        DO NW=1,NWQV
          IF( ISTRWQ(NW) > 0 )THEN
            NT = MSVWQV(NW)
            CBS(II,1,NT) = WQOBCS(LL,1,NW)
            CBS(II,2,NT) = WQOBCS(LL,2,NW)
          ENDIF
        ENDDO

      END IF
    END IF
  END DO

  write(mpi_mapping_unit,'(A)') ' '
  write(mpi_mapping_unit,'( 48("*"),A14,45("*") )' )  ' EUTRO SOUTH  '
  write(mpi_mapping_unit,'(2( " ****",2("****"),a8,3("****"),"|") )' ) 'GLOBAL ', 'LOCAL '
  write(mpi_mapping_unit,'(2(a5,5a8,1x))') 'N','IOPEN','JOPEN','WQ-SER','DO-BOT','DO-TOP','N','IOPEN','JOPEN','WQ-SER','DO-BOT','DO-TOP'
  DO II = 1,NWQOBS
    LL = LLSave(II)
    write(mpi_mapping_unit,'(2(I5,3I8,2F8.1,1X))') LL, ITMP(LL),   JTMP(LL),   IWQOBS(LL,IDOX), WQOBCS(LL,1,IDOX), WQOBCS(LL,2,IDOX), &
                                                    II, IWQCBS(II), JWQCBS(II), NCSERS(II,8),  CBS(II,1,IDOX),    CBS(II,2,IDOX)
  ENDDO
  DEALLOCATE(ITMP, JTMP)

  ! *** West
  NCBW_GL = NWQOBW
  ALLOCATE(ITMP(NWQOBW), JTMP(NWQOBW))
  ITMP = IWQCBW
  JTMP = JWQCBW
  
  NWQOBW = 0
  IWQCBW = 0
  JWQCBW = 0
  II = 0
  DO LL =1,NCBW_GL
    III = IG2IL(ITMP(LL))
    JJJ = JG2JL(JTMP(LL))
    IF(  III .GT. 0 .AND. III <= IC )THEN
      IF(  JJJ .GT. 0 .AND. JJJ <= JC )THEN
        II = II +1
        LLSave(II) = LL

        NWQOBW = NWQOBW + 1
        IWQCBW(II) = III
        JWQCBW(II) = JJJ

        ! *** CONCENTRATION SERIES ASSIGNMENTS
        IF( IWQCBW(II) == IG2IL(ICBW_GL(LL)) .AND. JWQCBW(II) == JG2JL(JCBW_GL(LL)) )THEN
          NCSERW(II,8) = IWQOBW(LL,IDOX)   ! *** ALL CONSTITUENTS USE THE SAME SERIES
        ELSE
          CALL STOPP('WQ: WEST OBC: MISS MATCH BETWEEN NCBW & NWQOBW')
        ENDIF

        DO NW=1,NWQV
          IF( ISTRWQ(NW) > 0 )THEN
            NT = MSVWQV(NW)
            CBW(II,1,NT) = WQOBCW(LL,1,NW)
            CBW(II,2,NT) = WQOBCW(LL,2,NW)
          ENDIF
        ENDDO

      END IF
    END IF
  END DO

  write(mpi_mapping_unit,'(A)') ' '
  write(mpi_mapping_unit,'( 48("*"),A14,45("*") )' )  ' EUTRO WEST   '
  write(mpi_mapping_unit,'(2( " ****",2("****"),a8,3("****"),"|") )' ) 'GLOBAL ', 'LOCAL '
  write(mpi_mapping_unit,'(2(a5,5a8,1x))') 'N','IOPEN','JOPEN','WQ-SER','DO-BOT','DO-TOP','N','IOPEN','JOPEN','WQ-SER','DO-BOT','DO-TOP'
  DO II = 1,NWQOBW
    LL = LLSave(II)
    write(mpi_mapping_unit,'(2(I5,3I8,2F8.1,1X))') LL, ITMP(LL),   JTMP(LL),   IWQOBW(LL,IDOX), WQOBCW(LL,1,IDOX), WQOBCW(LL,2,IDOX), &
                                                    II, IWQCBW(II), JWQCBW(II), NCSERW(II,8),  CBW(II,1,IDOX),    CBW(II,2,IDOX)
  ENDDO
  DEALLOCATE(ITMP, JTMP)

  ! *** East
  NCBE_GL = NWQOBE ! Set global copy
  ALLOCATE(ITMP(NWQOBE), JTMP(NWQOBE))
  ITMP = IWQCBE
  JTMP = JWQCBE
  
  NWQOBE = 0 
  IWQCBE = 0
  JWQCBE = 0
  II = 0
  DO LL =1,NCBE_GL
    III = IG2IL(ITMP(LL))
    JJJ = JG2JL(JTMP(LL))
    IF(  III .GT. 0 .AND. III <= IC )THEN
      IF(  JJJ .GT. 0 .AND. JJJ <= JC )THEN
        II = II + 1
        LLSave(II) = LL

        NWQOBE = NWQOBE + 1
        IWQCBE(II) = III
        JWQCBE(II) = JJJ

        ! *** CONCENTRATION SERIES ASSIGNMENTS
        IF( IWQCBE(II) == IG2IL(ICBE_GL(LL)) .AND. JWQCBE(II) == JG2JL(JCBE_GL(LL)) )THEN
          NCSERE(II,8) = IWQOBE(LL,IDOX)   ! *** ALL CONSTITUENTS USE THE SAME SERIES
        ELSE
          CALL STOPP('WQ: EAST OBC: MISS MATCH BETWEEN NCBE & NWQOBE')
        ENDIF

        DO NW=1,NWQV
          IF( ISTRWQ(NW) > 0 )THEN
            NT = MSVWQV(NW)
            CBE(II,1,NT) = WQOBCE(LL,1,NW)
            CBE(II,2,NT) = WQOBCE(LL,2,NW)
          ENDIF
        ENDDO

      END IF
    END IF
  END DO

  write(mpi_mapping_unit,'(A)') ' '
  write(mpi_mapping_unit,'( 48("*"),A14,45("*") )' )  ' EUTRO EAST   '
  write(mpi_mapping_unit,'(2( " ****",2("****"),a8,3("****"),"|") )' ) 'GLOBAL ', 'LOCAL '
  write(mpi_mapping_unit,'(2(a5,5a8,1x))') 'N','IOPEN','JOPEN','WQ-SER','DO-BOT','DO-TOP','N','IOPEN','JOPEN','WQ-SER','DO-BOT','DO-TOP'
  DO II = 1,NWQOBE
    LL = LLSave(II)
    write(mpi_mapping_unit,'(2(I5,3I8,2F8.1,1X))') LL, ITMP(LL),   JTMP(LL),   IWQOBE(LL,IDOX), WQOBCE(LL,1,IDOX), WQOBCE(LL,2,IDOX), &
                                                    II, IWQCBE(II), JWQCBE(II), NCSERE(II,8),  CBE(II,1,IDOX),    CBE(II,2,IDOX)
  ENDDO
  DEALLOCATE(ITMP, JTMP)
  
  ! *** North boundary
  NCBN_GL = NWQOBN
  ALLOCATE(ITMP(NWQOBN), JTMP(NWQOBN))
  ITMP = IWQCBN
  JTMP = JWQCBN

  NWQOBN = 0
  IWQCBN = 0
  JWQCBN = 0
  II = 0
  DO LL =1,NCBN_GL
    III = IG2IL(ITMP(LL))
    JJJ = JG2JL(JTMP(LL))
    IF(  III .GT. 0 .AND. III <= IC )THEN
      IF(  JJJ .GT. 0 .AND. JJJ <= JC )THEN
        II = II +1
        LLSave(II) = LL
        
        NWQOBN = NWQOBN + 1
        IWQCBN(II) = III
        JWQCBN(II) = JJJ

        ! *** CONCENTRATION SERIES ASSIGNMENTS
        IF( IWQCBN(II) == IG2IL(ICBN_GL(LL)) .AND. JWQCBN(II) == JG2JL(JCBN_GL(LL)) )THEN
          NCSERN(II,8) = IWQOBN(LL,IDOX)   ! *** ALL CONSTITUENTS USE THE SAME SERIES
        ELSE
          CALL STOPP('WQ: NORTH OBC: MISS MATCH BETWEEN NCBN & NWQOBN')
        ENDIF

        DO NW=1,NWQV
          IF( ISTRWQ(NW) > 0 )THEN
            NT = MSVWQV(NW)
            CBN(II,1,NT) = WQOBCN(LL,1,NW)
            CBN(II,2,NT) = WQOBCN(LL,2,NW)
          ENDIF
        ENDDO

      END IF
    END IF
  END DO

  write(mpi_mapping_unit,'(A)') ' '
  write(mpi_mapping_unit,'( 48("*"),A14,45("*") )' )  ' EUTRO NORTH  '
  write(mpi_mapping_unit,'(2( " ****",2("****"),a8,3("****"),"|") )' ) 'GLOBAL ', 'LOCAL '
  write(mpi_mapping_unit,'(2(a5,5a8,1x))') 'N','IOPEN','JOPEN','WQ-SER','DO-BOT','DO-TOP','N','IOPEN','JOPEN','WQ-SER','DO-BOT','DO-TOP'
  DO II = 1,NWQOBN
    LL = LLSave(II)
    write(mpi_mapping_unit,'(2(I5,3I8,2F8.1,1X))') LL, ITMP(LL),   JTMP(LL),   IWQOBN(LL,IDOX), WQOBCN(LL,1,IDOX), WQOBCN(LL,2,IDOX), &
                                                    II, IWQCBN(II), JWQCBN(II), NCSERN(II,8),  CBN(II,1,IDOX),    CBN(II,2,IDOX)
  ENDDO

  Call WriteBreak(mpi_mapping_unit)
  
  write(mpi_mapping_unit, '(a,I5)') ' '
  write(mpi_mapping_unit, '(a,I5)') 'Local NWQOBW  = ',  NWQOBW
  write(mpi_mapping_unit, '(a,I5)') 'Local NWQOBE  = ',  NWQOBE
  write(mpi_mapping_unit, '(a,I5)') 'Local NWQOBN  = ',  NWQOBN
  write(mpi_mapping_unit, '(a,I5)') 'Local NWQOBS  = ',  NWQOBS

  RETURN

  End Subroutine Map_OpenBC_Eutrophication
