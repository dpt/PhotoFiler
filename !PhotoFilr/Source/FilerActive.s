; Routine to check if the Filer is currently active

        GET     Hdr.Debug
        GET     Hdr.Flags
        GET     Hdr.Macros
        GET     Hdr.Options
        GET     Hdr.Symbols
        GET     Hdr.Workspace

        EXPORT  filer_active

        AREA    |filer_active_code|, CODE, READONLY


filer_active
        ; Purpose: Is the currently active task the Filer?
        ; Exit:    EQ if it is; NE otherwise

        Push    "r1, r14"

        MOV     r0, #5
        SWI     XWimp_ReadSysInfo
        ; R0 => current task handle
        ; R1 => Wimp version specified to Wimp_Initialise

        LDR     r1, [r12, #Filer_TaskHandle]
        TEQ     r0, r1

        Pull    "r1, pc"


        END
