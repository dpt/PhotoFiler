; String operations

        EXPORT  strcpy
        EXPORT  strncpy
        EXPORT  stricmp
        EXPORT  strin
        EXPORT  strmatch

        AREA    |strings_code|, CODE, READONLY


strcpy
        ; Purpose: Copies string from source to destination, ctrl terminated.
        ; Entry:   R1 -> source
        ;          R2 -> destination

        STMFD	r13!, {r1, r2, r14}
00
        LDRB    r14, [r1], #1
        CMP     r14, #' '
        MOVCC   r14, #0
        STRB    r14, [r2], #1
        BCS     %BT00
        LDMFD	r13!, {r1, r2, pc}


strncpy
        ; Purpose: Copies string from source to destination, zero terminated.
        ; Entry:   R1 -> source
        ;          R2 -> destination
        ;          R3 = maximum number of characters to copy (exc.terminator)

        STMFD   r13!, {r1-r3, r14}
        ADD     r3, r1, r3
00
        CMP     r1, r3                          ; exceeded length?
        MOVEQ   r14, #0                         ; force a stop
        LDRNEB  r14, [r1], #1
        CMP     r14, #' '
        MOVLT   r14, #0
        STRB    r14, [r2], #1
        BGE     %BT00
        LDMFD   r13!, {r1-r3, pc}


stricmp
        ; Purpose: Compares two strings for equality, returning flags.
        ; Entry:   R1 -> string 0
        ;          R2 -> string 1
        ; Exit:    EQ if strings are equal; NE otherwise

        STMFD   r13!, {r1-r4, r14}
00
        LDRB    r3, [r1], #1

        CMP     r3, #'a'                        ; upper case
        RSBGES  r14, r3, #'z'
        SUBGE   r3, r3, #'a' - 'A'

        LDRB    r4, [r2], #1

        CMP     r4, #'a'                        ; upper case
        RSBGES  r14, r4, #'z'
        SUBGE   r4, r4, #'a' - 'A'

        CMP     r3, #' '
        CMPLT   r4, #' '
        BLT	%FT10				; equal

        TEQ     r3, r4
        BEQ     %BT00

        LDMFD   r13!, {r1-r4, pc}               ; ne, return with flags

10
	TEQ	r0, r0				; set Z => EQ
	LDMFD   r13!, {r1-r4, pc}


strin
        ; Purpose: Find case-insensitive substring position.
        ; Entry:   R1 -> string
        ;          R2 -> substring
        ;          R3 = start position
        ; Exit:    R0 = length

        STMFD   r13!, {r1-r9, r14}

        LDRB    r5, [r2], #1
        CMP     r5, #' '
        BLT     strin_exit_lt   	; substring is empty

        CMP	r5, #'A'		; lowercase R5
        RSBGES	r14, r5, #'Z'
        ADDGE	r5, r5, #' '

        ADD     r1, r1, r3              ; set start position
        SUB     r3, r1, r3              ; compensate counter
strin_loop
        LDRB    r4, [r1], #1
        CMP     r4, #' '
strin_exit_lt
        MOVLT   r0, #-1
        LDMLTFD r13!, {r1-r9, pc}       ; substring not found

        CMP	r4, #'A'		; lowercase R4
        RSBGES	r14, r4, #'Z'
        ADDGE	r4, r4, #' '

        TEQ     r4, r5
        BNE     strin_loop

        MOV     r6, r1                  ; matched first char of substring
        MOV     r7, r2
strin_matched
        LDRB    r8, [r6], #1            ; string
        LDRB    r9, [r7], #1            ; substring
        CMP     r9, #' '
        SUBLT   r0, r1, #1              ; compensate for earlier post-inc
        SUBLT   r0, r0, r3
        LDMLTFD r13!, {r1-r9, pc}

        CMP	r8, #'A'		; lowercase R8
        RSBGES	r14, r8, #'Z'
        ADDGE	r8, r8, #' '

        CMP	r9, #'A'		; lowercase R9
        RSBGES	r14, r9, #'Z'
        ADDGE	r9, r9, #' '

        TEQ     r8, r9
        BEQ     strin_matched   	; keep going
        BNE     strin_loop              ; substring match failed


strmatch
        ; Purpose: Match a string, with wildcards '*' and '?'
        ; Entry:   R1 -> wildcarded string
        ;          R2 -> string to match
        ; Exit:    EQ if strings matched; NE otherwise
        ;          Registers preserved
        ;
        ; ### NOT CASE INSENSITIVE!
        ;
        ; ### NOT EVEN SURE THIS WORKS!

        STMFD   r13!, {r1-r4, r14}
        BL      a
        LDMFD   r13!, {r1-r4, pc} 	; return with new flags

a
        LDRB    r3, [r1], #1
        TEQ     r3, #'*'
        BNE     d
b
        LDRB    r3, [r1], #1
        TEQ     r3, #'*'
        BEQ     b
        TEQ     r3, #0
        BEQ     e
c
        LDRB    r4, [r2], #1
        TEQ     r4, #0
        BEQ     g
        TEQ     r3, r4
        TEQNE   r3, #'?'
        BNE     c
        B       strmatch        	; recurse
d
        LDRB    r4, [r2], #1
        TEQ     r4, #0
        BNE     f
        TEQ     r3, #0
        BNE     g
e
	TEQ	r0, r0			; match, set Z
        MOV     pc, r14         	; return with new flags
f
        TEQ     r3, r4
        TEQNE   r3, #'?'
        BEQ     a
g
        TEQ	pc, #0			; no match, clear Z
        MOV     pc, r14         	; return with new flags


        END
