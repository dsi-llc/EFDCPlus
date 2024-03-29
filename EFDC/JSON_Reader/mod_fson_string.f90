! ----------------------------------------------------------------------
!   This file is a part of EFDC+
!   Website:  https://eemodelingsystem.com/
!   Repository: https://github.com/dsi-llc/EFDC_Plus.git
! ----------------------------------------------------------------------
! Copyright 2021-2022 DSI, LLC
! Distributed under the GNU GPLv2 License.
! ----------------------------------------------------------------------
! Copyright (c) 2012 Joseph A. Levin
!
! Permission is hereby granted, free of charge, to any person obtaining a copy of this
! software and associated documentation files (the "Software"), to deal in the Software
! without restriction, including without limitation the rights to use, copy, modify, merge,
! publish, distribute, sublicense, and/or sell copies of the Software, and to permit 
! persons to whom the Software is furnished to do so, subject to the following conditions:
!
! The above copyright notice and this permission notice shall be included in all copies or 
! substantial portions of the Software.
!
! THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
! INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
! PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE 
! LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT
! OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
! DEALINGS IN THE SOFTWARE.

!     
! File:   string.f95
! Author: josephalevin
!
! Created on March 7, 2012, 7:40 PM
!

module mod_fson_string

    private

    public :: fson_string, fson_string_create, fson_string_destroy, fson_string_length, fson_string_append 
    public :: fson_string_equals, fson_string_copy

    integer, parameter :: BLOCK_SIZE = 32

    type fson_string
        character (len = BLOCK_SIZE) :: chars
        integer :: index = 0
        type(fson_string), pointer :: next => null()
    end type fson_string

    interface fson_string_append
        module procedure append_chars, append_string
    end interface fson_string_append

    interface fson_string_copy
        module procedure copy_chars
    end interface fson_string_copy

    interface fson_string_equals
        module procedure equals_string
    end interface fson_string_equals
    
    interface fson_string_length
        module procedure string_length
    end interface fson_string_length

contains

    !
    ! FSON STRING CREATE
    !
    function fson_string_create(chars) result(new)
        character(len=*), optional :: chars
        type(fson_string), pointer :: new

        nullify(new)
        allocate(new)
        
        ! append chars if available
        if(present(chars) )then
            call append_chars(new, chars)
        end if

    end function fson_string_create
    
    !
    ! FSON STRING CREATE
    !
    recursive subroutine fson_string_destroy(this)

      implicit none
      type(fson_string), pointer :: this

      IF( associated(this) )then

         if(associated(this.next) )then
            call fson_string_destroy(this.next)
         end if

         deallocate(this)
         nullify (this)

      end if

    end subroutine fson_string_destroy

    !
    ! ALLOCATE BLOCK
    !
    subroutine allocate_block(this)

      implicit none
      type(fson_string), pointer :: this
      type(fson_string), pointer :: new

      IF( .not.associated(this.next) )then
         nullify(new)
         allocate(new)
         this.next => new
      end if

    end subroutine allocate_block


    !
    ! APPEND_STRING
    !
    subroutine append_string(str1, str2)
        type(fson_string), pointer :: str1, str2
        integer length, i

        length = string_length(str2)

        do i = 1, length
            call append_char(str1, get_char_at(str2, i))
        end do


    end subroutine append_string

    !
    ! APPEND_CHARS
    !
    subroutine append_chars(str, c)
        type(fson_string), pointer :: str
        character (len = *), intent(in) :: c
        integer length, i

        length = len(c)

        do i = 1, length
            call append_char(str, c(i:i))
        end do


    end subroutine append_chars

    !
    ! APPEND_CHAR
    !
    recursive subroutine append_char(str, c)
        type(fson_string), pointer :: str
        character, intent(in) :: c

        IF( str.index .GE. BLOCK_SIZE )then
            !set down the chain
            call allocate_block(str)
            call append_char(str.next, c)

        else
            ! set local
            str.index = str.index + 1
            str.chars(str.index:str.index) = c
        end if

    end subroutine append_char

    !
    ! COPY CHARS
    !
    subroutine copy_chars(this, to)
        type(fson_string), pointer :: this
        character(len = *), intent(inout) :: to
        integer :: length, i

        length = min(string_length(this), len(to))

        do i = 1, length
            to(i:i) = get_char_at(this, i)
        end do

        ! pad with nothing
        do i = length + 1, len(to)
            to(i:i) = ""
        end do


    end subroutine copy_chars



    !
    ! CLEAR
    !
    recursive subroutine string_clear(this)
        type(fson_string), pointer :: this

        IF( associated(this.next) )then
            call string_clear(this.next)
            deallocate(this.next)
            nullify (this.next)
        end if

        this.index = 0

    end subroutine string_clear

    !
    ! SIZE    
    !
    recursive integer function string_length(str) result(count)
        type(fson_string), pointer :: str

        count = str.index

        IF( str.index == BLOCK_SIZE .AND. associated(str.next) )then
            count = count + string_length(str.next)
        end if

    end function string_length


    !
    ! GET CHAR AT
    !
    recursive character function get_char_at(this, i) result(c)
        type(fson_string), pointer :: this
        integer, intent(in) :: i

        IF( i .LE. this.index )then
            c = this.chars(i:i)
        else
            c = get_char_at(this.next, i - this.index)
        end if

    end function get_char_at

    !
    ! EQUALS STRING
    !
    logical function equals_string(this, other) result(equals)
        type(fson_string), pointer :: this, other
        integer :: i
        equals = .false.
        
        if(fson_string_length(this) .ne. fson_string_length(other) )then
            equals = .false.
            return
        else if(fson_string_length(this) == 0 )then
            equals = .true.
            return
        end if
        
        do i=1, fson_string_length(this)
            if(get_char_at(this, i) .ne. get_char_at(other, i) )then
                equals = .false.
                return
            end if
        end do
        
        equals = .true.
        
    end function equals_string

end module mod_fson_string
