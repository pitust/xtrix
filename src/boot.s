; kernel assembly entrypoint and stivale1 structure
; Copyright (C) 2021 pitust <piotr@stelmaszek.com>

; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.

; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.

; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <https://www.gnu.org/licenses/>.


section .text
global _start
extern kmain
_start:
    call kmain
.e:
    hlt
    jmp .e

section .stivalehdr
    dq stack_top    ; stack
    dw 9            ; flags (framebuffer and higher half ptrs)
    dw 0            ; fb width
    dw 0            ; fb height
    dw 32           ; bpp
    dq 0            ; entry

section .bss
stack_bottom:
    resb 0x8000
stack_top:
