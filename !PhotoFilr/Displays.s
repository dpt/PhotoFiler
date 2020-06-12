; Display block handling

        GET     Hdr.Debug
        GET     Hdr.Flags
        GET     Hdr.Options
        GET     Hdr.Symbols
        GET     Hdr.Workspace

        EXPORT  find_display

        AREA    |displays_code|, CODE, READONLY


find_display
        ; Purpose: Locate the display block for the current window
        ; Exit:    R7 = display block
        ;          EQ if the display is known, NE otherwise

        STMFD   r13!, {r1, r14}

        LDR     r1, [r12, #Window_Block]
        LDR     r7, [r12, #Display_First]
0
        TEQ     r7, #0
        BEQ     not_found

        LDR     r14, [r7, #Display_Handle]
        TEQ     r14, r1
        LDRNE   r7, [r7, #Display_Next]
        BNE     %B0

        LDMFD   r13!, {r1, pc}                  ; return R7, EQ implied

not_found
        TEQ     pc, #0                          ; set nz..
        LDMFD   r13!, {r1, pc}                  ; return NE

        END
