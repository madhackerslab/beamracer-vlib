;****************************************************************************
;* Header file for BeamRacer VASYL chip
;* 2019-2020 MHL
;* See https://docs.beamracer.net/ for more information.
;*
;* Compatible with ca65 assembler (part of https://github.com/cc65).
;****************************************************************************

; Macros for assembling VASYL opcodes.

.macro WAIT v, h
        .dbyt (v & $01ff) | ((h & $3f) << 9)
.endmacro

.macro DELAYH v, h
        .ifblank h  ; this means only one arg was given
                    ; so "v" actually the horizontal delay
            .byte %10110000, (v & $3f)
        .else
            .byte %10110000, ((v & $03) << 6) | (h & $3f)
        .endif
.endmacro

.macro DELAYV v
        .dbyt (%10111000 << 8) | (v & $01ff)
.endmacro

.macro MASKH h
        .byte %10110100, (h & $3f)
.endmacro
.macro MASKV v
        .dbyt (%10111100 << 8) |  (v & $01ff)
.endmacro

.macro MASKPH h
        .byte %10110110, (h & $3f)
.endmacro
.macro MASKPV v
        .dbyt (%10111110 << 8)|  (v & $01ff)
.endmacro

.macro SETA v
        .byte %10110010, (v & $ff)
.endmacro

.macro SETB v
        .byte %10110011, (v & $ff)
.endmacro

.macro DECA
        .byte %10100000
.endmacro

.macro DECB
        .byte %10100001
.endmacro

.macro MOV reg, value
        .if (reg & $ff) < VREG_MAX && (((reg & $ff00) = VIC_BASE) || ((reg & $ff00) = $0))
            .if (reg & $ff) < VREG_INT
                .byte $c0 | (reg & $3f), (value & $ff)
            .else
                .byte $80 | ((reg - VREG_INT) & $0f), (value & $ff)
            .endif
        .else
            .error .sprintf("MOV: register out of range: $%x", reg);
        .endif
.endmacro

.macro SKIP
        .byte %10100110
.endmacro

.macro IRQ
        .byte %10100010
.endmacro

.macro VNOP
        .byte %10100111
.endmacro

.macro WAITBAD
        .byte %10100100
.endmacro

.macro BADLINE l
        .byte %10101000 | (l & $07)
.endmacro

.macro XFER v, c
        .byte %10100101, ((c & 1) << 7) | (v - VIC_BASE)
.endmacro

.macro BRA target
        .if .const (target)
            .if target >= -128 && target <= 127
                .byte %10100011, target
            .else
                .error .sprintf ("BRA: target out of range: %d bytes away", target)
            .endif
        .else
            .ifndef target
                .byte %10100011, (target - (* + 1)) & $ff
                .warning "Forward BRA assembled without bounds checking."
            .else
                .if (target -(* + 1)) >= -128 && (target -(* + 1)) <= 127
                    .byte %10100011, (target - (* + 1)) & $ff
                .else
                    .error .sprintf ("BRA: target out of range: %s is %d bytes away", .string(target), target -(* + 1))
                .endif
            .endif
        .endif
.endmacro

.macro END
        WAIT $1ff, $3f
.endmacro


; Registers ($d031-$d03f, read-write)
.ifndef VIC_BASE
    VIC_BASE   = $d000
.endif

VREG_BASE            = $d030
VREG_INT             = $40
VREG_MAX             = $4f
VREG_CONTROL         = VREG_BASE + $01
VREG_DLIST           = VREG_BASE + $02
VREG_DLISTL          = VREG_BASE + $02
VREG_DLISTH          = VREG_BASE + $03
VREG_ADR0            = VREG_BASE + $04
VREG_STEP0           = VREG_BASE + $06
VREG_PORT0           = VREG_BASE + $07
VREG_ADR1            = VREG_BASE + $08
VREG_STEP1           = VREG_BASE + $0a
VREG_PORT1           = VREG_BASE + $0b
VREG_REP0            = VREG_BASE + $0c
VREG_REP1            = VREG_BASE + $0d
VREG_DLSTROBE        = VREG_BASE + $0e
VREG_RESERVED        = VREG_BASE + $0f

; Internal registers ($d040-$d04f, write-only, not system-bus accessible)
VREG_PBS_CONTROL     = VREG_BASE + $10
VREG_DLIST2          = VREG_BASE + $11
VREG_DLIST2L         = VREG_BASE + $11
VREG_DLIST2H         = VREG_BASE + $12
VREG_DL2STROBE       = VREG_BASE + $13
VREG_PBS_BASEL       = VREG_BASE + $14
VREG_PBS_BASEH       = VREG_BASE + $15
VREG_PBS_START_CYCLE = VREG_BASE + $16
VREG_PBS_STOP_CYCLE  = VREG_BASE + $17
VREG_PBS_STEPL       = VREG_BASE + $18
VREG_PBS_STEPH       = VREG_BASE + $19
VREG_PBS_PADDINGL    = VREG_BASE + $1a
VREG_PBS_PADDINGH    = VREG_BASE + $1b
VREG_PBS_XORBYTE     = VREG_BASE + $1c
VREG_PBS_RESERVED0   = VREG_BASE + $1d
VREG_PBS_RESERVED1   = VREG_BASE + $1e
VREG_PBS_RESERVED2   = VREG_BASE + $1f


; Opcode masks and values.
;
; *_MASK has "one" bits in locations which must be matching with
; corresponding *_VALUE bits to recognize given instruction. For instance:
;    lda #opcode
;    and #VASYL_BADLINE_MASK
;    cmp #VASYL_BADLINE_VALUE
;    beq opcode_is_badline_instruction

VASYL_BADLINE_MASK    = %11111000
VASYL_BADLINE_VALUE   = %10101000
VASYL_BRA_MASK        = %11111111
VASYL_BRA_VALUE       = %10100011
VASYL_DECAB_MASK      = %11111110
VASYL_DECAB_VALUE     = %10100000
VASYL_DELAYH_MASK     = %11111000 ; also includes the mask for MASKH
VASYL_DELAYH_VALUE    = %10110000
VASYL_DELAYV_MASK     = %11111000 ; also includes the mask for MASKV
VASYL_DELAYV_VALUE    = %10111000
VASYL_IRQ_MASK        = %11111111
VASYL_IRQ_VALUE       = %10100010
VASYL_MASKH_MASK      = %11111110
VASYL_MASKH_VALUE     = %10110100
VASYL_MASKPH_MASK     = %11111110
VASYL_MASKPH_VALUE    = %10110110
VASYL_MASKPV_MASK     = %11111110
VASYL_MASKPV_VALUE    = %10111110
VASYL_MASKV_MASK      = %11111110
VASYL_MASKV_VALUE     = %10111100
VASYL_MOVI_MASK       = %11100000
VASYL_MOVI_VALUE      = %10000000
VASYL_MOV_MASK        = %11000000
VASYL_MOV_VALUE       = %11000000
VASYL_VNOP_MASK       = %11111111
VASYL_VNOP_VALUE      = %10100111
VASYL_SETAB_MASK      = %11111110
VASYL_SETAB_VALUE     = %10110010
VASYL_SKIP_MASK       = %11111111
VASYL_SKIP_VALUE      = %10100110
VASYL_WAITBAD_MASK    = %11111111
VASYL_WAITBAD_VALUE   = %10100100
VASYL_WAITREP_MASK    = %11111110
VASYL_WAITREP_VALUE   = %10111010
VASYL_WAIT_MASK       = %10000000
VASYL_WAIT_VALUE      = %00000000
VASYL_XFER_MASK       = %11111111
VASYL_XFER_VALUE      = %10100101


; Constants
MEMBANK_COUNT = 8

CONTROL_RAMBANK_BIT             = 0 ; bits 0-2
CONTROL_DLIST_ON_BIT            = 3
CONTROL_RAMBANK_MASK            = (%111 << CONTROL_RAMBANK_BIT)
CONTROL_PORT_READ_ENABLE_BIT    = 4
CONTROL_GRAYDOT_KILL_BIT        = 5
CONTROL_PORT_COPY_BIT           = 6
CONTROL_RESERVED                = 7

PBS_CONTROL_ACTIVE_BIT          = 3
PBS_CONTROL_RAMBANK_BIT         = 0 ; bits 0-2
PBS_CONTROL_RAMBANK_MASK        = (%111 << PBS_CONTROL_RAMBANK_BIT)
PBS_CONTROL_UPDATE_BIT          = 4 ; bits 4-5
PBS_CONTROL_UPDATE_MASK         = (%11 << PBS_CONTROL_UPDATE_BIT)
PBS_CONTROL_UPDATE_NONE         = (%00 << PBS_CONTROL_UPDATE_BIT)
PBS_CONTROL_UPDATE_EOL          = (%01 << PBS_CONTROL_UPDATE_BIT)
PBS_CONTROL_UPDATE_ALWAYS       = (%10 << PBS_CONTROL_UPDATE_BIT)
PBS_CONTROL_SWIZZLE_BIT         = 6 ; bits 6-7
PBS_CONTROL_SWIZZLE_MASK        = (%11 << PBS_CONTROL_SWIZZLE_BIT)
PBS_CONTROL_SWIZZLE_NONE        = (%00 << PBS_CONTROL_SWIZZLE_BIT)
PBS_CONTROL_SWIZZLE_MIRROR      = (%01 << PBS_CONTROL_SWIZZLE_BIT)
PBS_CONTROL_SWIZZLE_MULTIMIRROR = (%10 << PBS_CONTROL_SWIZZLE_BIT)

