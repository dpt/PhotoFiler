; Wrapper for Wimp_RedrawWindow and Wimp_UpdateWindow

        GET     Hdr.Debug
        GET     Hdr.Flags
        GET     Hdr.Options
        GET     Hdr.Symbols
        GET     Hdr.Workspace

        EXPORT  wimp_redrawwindow_pre
        EXPORT  wimp_updatewindow_pre

        AREA    |redrawwindow_code|, CODE, READONLY


wimp_redrawwindow_pre
wimp_updatewindow_pre
        STR     r14, [r13, #-4]!                ; STMFD r13!, {r14}

        LDR     r14, [r1]                       ; update the current
        STR     r14, [r12, #Window_Block]       ;  display handle

        LDR     pc, [r13], #4                   ; LDMFD r13!, {pc}


        END
