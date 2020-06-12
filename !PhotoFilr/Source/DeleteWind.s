; Wrapper for Wimp_DeleteWindow

        GET     Hdr.Debug
        GET     Hdr.Flags
        GET     Hdr.Macros
        GET     Hdr.Options
        GET     Hdr.Symbols
        GET     Hdr.Workspace

        IMPORT  delete_thumbnail
        IMPORT  heap_release
        IMPORT  filer_active

        EXPORT  wimp_deletewindow_pre

        AREA    |deletewindow_code|, CODE, READONLY


wimp_deletewindow_pre
        ; Purpose: Called before Wimp_CreateWindow.
        ; Purpose: Remove all of our associated structures when the Filer
        ;          deletes a display.

        Push    "r0-r1, r6-r8, r14"

        BL      filer_active
        BNE     exit                            ; filer is not active

        LDR     r1, [r1]                        ; get display window handle
        ADD     r6, r12, #Display_First         ; for later
        LDR     r7, [r12, #Display_First]
window
        TEQ     r7, #0                          ; end of window list?
        BEQ     exit                            ; yes

        LDR     r0, [r7, #Display_Handle]
        TEQ     r0, r1                          ; is it our window?
        ADDNE   r6, r7, #Display_Next
        LDRNE   r7, [r7, #Display_Next]
        BNE     window

        SWI     XHourglass_On

        LDR     r8, [r7, #Display_FirstIcon]    ; found the window
icon
        TEQ     r8, #0                          ; end of icon list?
        BEQ     nomoreicons
        MOV     r0, r8                          ; for heap_release
        BL      delete_thumbnail
        LDR     r8, [r8, #Icon_Next]
        BL      heap_release                    ; release icon block
        B       icon

nomoreicons
        MOV     r0, r7                          ; for heap_release
        LDR     r7, [r7, #Display_Next]         ; adjust chain
        STR     r7, [r6]
        BL      heap_release                    ; release display block

        SWI     XHourglass_Off

exit
        Pull    "r0-r1, r6-r8, pc"


        END
