; struct stivale_header {
;     uint64_t stack;
;     uint16_t flags;
;     uint16_t framebuffer_width;
;     uint16_t framebuffer_height;
;     uint16_t framebuffer_bpp;
;     uint64_t entry_point;
; };
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
    resb 0x1000
stack_top: