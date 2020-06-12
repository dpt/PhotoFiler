; Wrapper for Wimp_RedrawWindow and Wimp_UpdateWindow

        GET     Hdr.Debug
        GET     Hdr.Flags
        GET     Hdr.Macros
        GET     Hdr.Options
        GET     Hdr.Symbols
        GET     Hdr.Workspace

        EXPORT  wimp_redrawwindow_pre
        EXPORT  wimp_updatewindow_pre

        AREA    |redrawwindow_code|, CODE, READONLY


wimp_redrawwindow_pre
wimp_updatewindow_pre
        Push    r14

        LDR     r14, [r1]                       ; update the current
        STR     r14, [r12, #Window_Block]       ;  display handle

        Pull    pc


        END
