; Wrappers for Wimp_CreateWindow

        GET     Hdr.Debug
        GET     Hdr.Flags
        GET     Hdr.Options
        GET     Hdr.Symbols
        GET     Hdr.Workspace

        IMPORT  filer_active
        IMPORT  heap_claim
        IMPORT  strcpy
        IMPORT  strmatch

        EXPORT  wimp_createwindow_pre
        EXPORT  wimp_createwindow_post

        AREA    |createwindow_code|, CODE, READONLY

wimp_createwindow_pre
        ; Purpose: Called before Wimp_CreateWindow.

        STMFD   r13!, {r0-r2, r14}

        DBF     "ENTER wimp_createwindow_pre\n"

        MOV     r14, #0                         ; clear the flag
        STR     r14, [r12, #CreateWindow]

        BL      filer_active
        BNE     %f99                            ; filer is not active

        MOV     r0, #121                        ; ignore if ctrl is being
        MOV     r1, #129                        ; held
        SWI     XOS_Byte
        TEQ     r1, #255
        BEQ     %f99

        LDR     r1, [r13, #4]                   ; ignore if the window does
        LDR     r0, [r1, #28]                   ; not look like a directory
        MOV     r0, r0, LSR #24                 ; display
        TEQ     r0, #&BF
        BNE     %f99

        LDR     r0, [r12, #Sprites_Base]        ; adjust the sprite area
        STR     r0, [r1, #64]                   ; pointer

        ; erk, in the above we're actually modifying the (Filer)
        ; application's window definition

        STR     pc, [r12, #CreateWindow]        ; set the flag

        DBF     "EXIT wimp_createwindow_pre\n"

99
        LDMFD   r13!, {r0-r2, pc}


wimp_createwindow_post
        ; Purpose: Called after Wimp_CreateWindow.
        ; Entry:   R0 = window handle
        ;          or potential VS state

        MOVVS   pc, r14                         ; exit if there was an error

        STMFD   r13!, {r0-r2, r7, r14}

        DBF     "ENTER wimp_createwindow_post\n"

        LDR     r14, [r12, #CreateWindow]       ; ignore if we did not handle
        TEQ     r14, #0                         ;  this window
        BEQ     %f99

        STR     r0, [r12, #Window_Block]
        ADD     r1, r12, #Window_Block
        ORR     r1, r1, #1                      ; return header only
        SWI     XWimp_GetWindowInfo
        BVS     %f99

        LDR     r2, [r12, #Window_Block + 76]   ; window title
        LDR     r0, [r12, #FSReject_First]
0
        TEQ     r0, #0
        BEQ     %f1
        ADD     r1, r0, #FSReject_Wildcard
        BL      strmatch
        BEQ     %f99
        LDR     r0, [r0, #FSReject_Next]
        B       %b0

1
        MOV     r0, #sizeof_display             ; claim space for blk
        BL      heap_claim
        BVS     %f99

        MOV     r7, r0                          ; block address
        LDR     r2, [r12, #Display_First]       ; chain in
        STR     r7, [r12, #Display_First]
        STR     r2, [r7, #Display_Next]

        LDR     r2, [r12, #Window_Block]        ; update window handle
        STR     r2, [r7, #Display_Handle]

        LDR     r1, [r12, #Window_Block + 76]   ; copy window path
        ADD     r2, r7, #Display_Path
        BL      strcpy

  [ HASHING <> 0
        ; ### fill the chain table with 0s
  |
        MOV     r0, #0
        STR     r0, [r7, #Display_FirstIcon]    ; no icons yet
  ]


        DBF     "EXIT wimp_createwindow_post\n"

99
        LDMFD   r13!, {r0-r2, r7, pc}

        END
