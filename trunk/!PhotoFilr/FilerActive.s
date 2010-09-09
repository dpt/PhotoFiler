; Routine to check if the Filer is currently active

        GET     Hdr.Debug
        GET     Hdr.Flags
        GET     Hdr.Options
        GET     Hdr.Symbols
        GET     Hdr.Workspace

        EXPORT  filer_active

        AREA    |filer_active_code|, CODE, READONLY


filer_active
        ; Purpose: Is the currently active task the Filer?
        ; Exit:    EQ if it is; NE otherwise

        STR	r14, [r13, #-4]!	; STMFD	r13!, {r14}

        ; Get lower 16 bits of current task handle and compare it to the
        ; domain ID. (v. hacky)
        ;
        LDR     r14, [r12, #Filer_TaskHandle]
        MOV     r0, #&F00
        LDR     r0, [r0, #&F8]
        MOV     r14, r14, LSL #16       ; clear top sixteen bits
        MOV     r14, r14, LSR #16
        TEQ     r0, r14

        LDR	pc, [r13], #4		; LDMFD	r13!, {pc}


        END
