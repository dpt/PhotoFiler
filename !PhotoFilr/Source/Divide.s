; Divide routine

        GET     Hdr.Macros

        EXPORT  divide

        AREA    |divide_code|, CODE, READONLY


; A macro to do unsigned integer division. It takes four parameters, each of
; which should be a register name:
;
; $Div: The macro places the quotient of the division in this register -
;       ie $Div := $Top DIV $Bot.
;       $Div may be omitted if only the remainder is wanted.
; $Top: The macro expects the dividend in this register on entry and places
;       the remainder in it on exit - ie $Top := $Top MOD $Bot.
; $Bot: The macro expects the divisor in this register on entry. It does not
;       alter this register.
; $Temp:The macro uses this register to hold intermediate results. Its initial
;       value is ignored and its final value is not useful.
;
; $Top, $Bot, $Temp and (if present) $Div must all be distinct registers.
; The macro does not check for division by zero; if there is a risk of this
; happening, it should be checked for outside the macro.

        MACRO
$label  DivMod  $div, $top, $bot, $temp
        ASSERT  $top <> $bot            ; Produce an error if the
        ASSERT  $top <> $temp           ; registers supplied are
        ASSERT  $bot <> $temp           ; not all different.
     [ "$div" <> ""
        ASSERT  $div <> $top
        ASSERT  $div <> $bot
        ASSERT  $div <> $temp
     ]
$label  MOV     $temp, $bot             ; Put the divisor in $Temp
        CMP     $temp, $top, LSR #1     ; Then double it until
90      MOVLS   $temp, $temp, LSL #1    ; 2 * $Temp > $Top.
        CMP     $temp, $top, LSR #1
        BLS     %b90
     [ "$div" <> ""
        MOV     $div, #0                ; Initialise the quotient.
     ]
91      CMP     $top, $temp             ; Can we subtract $Temp?
        SUBCS   $top, $top, $temp       ; If we can, do so.
     [ "$div" <> ""
        ADC     $div, $div, $div        ; Double $Div & add new bit
     ]
        MOV     $temp, $temp, LSR #1    ; Halve $Temp,
        CMP     $temp, $bot             ; and loop until we've gone
        BHS     %b91                    ; past the original divisor.
        MEND


divide
        ; Purpose: Divide.
        ; Entry:   R0 = dividend
        ;          R1 = divisor
        ; Exit:    R0 = quotient
        ;          R1 = remainder

        Push    "r2, r14"

        TEQ     r1, #0                          ; test for division by zero
        BEQ     divide_by_zero

        DivMod  r2, r0, r1, r14

        MOV     r1, r0                          ; remainder
        MOV     r0, r2                          ; quotient

        ; ### clear V?

        Pull    "r2, pc"

divide_by_zero
        ADR     r0, divide_by_zero_block
        MSR     cpsr_f, #1<<28                  ; set V
        Pull    "r2, pc"

divide_by_zero_block
        DCD     18                              ; error number from BASIC
        DCB     "Division by zero", 0
        ALIGN


        END
