; BeamRacer * https://beamracer.net
; Video and Display List coprocessor board for the Commodore 64
; Copyright (C)2019-2020 Mad Hackers Lab
;
; https://github.com/madhackerslab/
;
; Header file for BeamRacer VASYL chip
; See https://docs.beamracer.net/ for more information.
;
; Compatible with ca65 assembler (part of https://github.com/cc65).

.ifndef VREG_BASE
        .include "vasyl.s"
.endif

        .import __VASYL_LOAD__, __VASYL_SIZE__

tmp_ptr = 251
tmp_ptr2 = 253

; this only gets assembled if there is no knocking ahead of it
.ifnref knock_knock
autostart:
        jsr knock_knock

        ldx #$2e
@preserve_loop:
        lda $d000,x
        sta preserve_vic,x
        dex
        bpl @preserve_loop

        jsr copy_and_activate_dlist
@keyloop:
        jsr $ffe4   ; check if key pressed
        beq @keyloop

        cmp #3
        beq @no_restore

        lda #0      ; turn off display list
        sta VREG_CONTROL

        ldx #$2e
@preserve_loop2:
        lda preserve_vic,x
        sta $d000,x
        dex
        bpl @preserve_loop2
@no_restore:
        rts
preserve_vic:
        .res 47
.endif


.ifref knock_knock
; Attempt activation of the BeamRacer
; On failure (BeamRacer missing) exits the program
knock_knock:
        ldx #255
        cpx VREG_CONTROL
        bne @active
        lda #$42
        sta VREG_CONTROL
        lda #$52
        sta VREG_CONTROL
        cpx VREG_CONTROL
        bne @active
; exit the program
        pla
        pla
@active:
;        jsr print_info
        rts
.endif

.ifref copy_and_activate_dlist
; Copy a dlist to local RAM and activate it:
; the contents of segment "VASYL" is copied
; to address 0 in local RAM and then the display list
; is activated.

copy_and_activate_dlist:
        jsr copy_dlist
        ; start using the new Display List
        lda #<dl_start
        sta VREG_DLIST
        lda #>dl_start
        sta VREG_DLIST + 1
        lda #(1 << CONTROL_DLIST_ON_BIT)
        sta VREG_CONTROL
        rts
.endif

.ifref copy_dlist
; Copy a dlist to local RAM:
; the contents of segment "VASYL" is copied
; to address 0 in local RAM.
copy_dlist:
        lda #<__VASYL_LOAD__
        sta tmp_ptr
        lda #>__VASYL_LOAD__
        sta tmp_ptr + 1
        lda #0
        sta tmp_ptr2
        sta tmp_ptr2 + 1

        lda #<__VASYL_SIZE__
        ldx #>__VASYL_SIZE__
        jmp copy_to_lmem
.endif

.ifref copy_to_lmem
; Copy data to lram:
; $FA/$FB - source
; $FC/$FD - destination (in VASYL's local RAM)
; AX - lo/hi byte count
copy_to_lmem:
        ldy tmp_ptr2
        sty VREG_ADR0
        ldy tmp_ptr2 + 1
        sty VREG_ADR0 + 1
        ldy #1
        sty VREG_STEP0

        clc
        adc tmp_ptr
        sta tmp_ptr2
        txa
        adc tmp_ptr + 1
        sta tmp_ptr2 + 1

        ldy #0
@loop:
        lda (tmp_ptr),y
        sta VREG_PORT0
        inc tmp_ptr
        bne @no_carry
        inc tmp_ptr + 1
@no_carry:
        lda tmp_ptr2
        cmp tmp_ptr
        bne @loop
        lda tmp_ptr2 + 1
        cmp tmp_ptr + 1
        bne @loop
        rts
.endif

.ifref set_pages
; Set VASYL memory pages to a value.
; A - value
; Y - starting page
; X - page count
UNROLL_FACTOR = 8
set_pages:
        sty VREG_ADR0 + 1
        ldy #1
        sty VREG_STEP0
        dey ; 0
        sty VREG_ADR0
        dey ; 255
        sta VREG_PORT0  ; Store one byte.
@next_page:
        sty VREG_REP0   ; Repeat 255 times on first iteration, 256 on subsequent ones.
@waitrep:
        ldy VREG_REP0   ; Wait for REP transfer to end.
        bne @waitrep
        dex
        bne @next_page
        rts
.endif

.ifref print_info
; Print information about VASYL and VIC-II versions.
print_info:
        lda #<version_text
        ldy #>version_text
        jsr $ab1e   ; print null terminated string
        lda VREG_DLSTROBE
        lsr
        lsr
        lsr
        tax
        lda #0
        jsr $bdcd   ; print XA as unsigned integer
        lda #<type_text
        ldy #>type_text
        jsr $ab1e   ; print null terminated string

        lda VREG_DLSTROBE
        and #$07
        tax
        lda type_table_lo,x
        ldy type_table_hi,x
        jmp $ab1e   ; print null terminated string

version_text:
        .byte "vasyl ID: ",0
type_text:
        .byte $d,"vic-ii type  : ", 0
type_table_lo:
        .lobytes type_ntsc, type_unknown, type_unknown, type_ntsc_old
        .lobytes type_paln, type_unknown, type_pal, type_unknown
type_table_hi:
        .hibytes type_ntsc, type_unknown, type_unknown, type_ntsc_old
        .hibytes type_paln, type_unknown, type_pal, type_unknown
type_ntsc:
        .byte "ntsc (6567r8 or 8562)", 0
type_pal:
        .byte "pal (6569 or 8565)", 0
type_paln:
        .byte "pal-n (6572)", 0
type_ntsc_old:
        .byte "ntsc (6567r56a)", 0
type_unknown:
        .byte "unknown", 0
.endif

