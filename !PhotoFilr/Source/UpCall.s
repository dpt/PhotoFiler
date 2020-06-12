; UpCall handler

        GET     Hdr.Debug
        GET     Hdr.Flags
        GET     Hdr.Macros
        GET     Hdr.Options
        GET     Hdr.Symbols
        GET     Hdr.Workspace

  [ UPCALL_HANDLER <> 0

        IMPORT  delete_thumbnail
        IMPORT  heap_release
        IMPORT  stricmp

        EXPORT  upcall_on
        EXPORT  upcall_off

        AREA    |upcall_code|, CODE, READONLY

upcall_on
        ; Entry: R12 -> workspace

        Push    "r0-r2, r14"

        MOV     r0, #UpCallV
        ADR     r1, upcall_handler
        MOV     r2, r12
        SWI     XOS_Claim

        Pull    "r0-r2, pc"


upcall_off
        ; Entry: R12 -> workspace

        Push    "r0-r2, r14"

        MOV     r0, #UpCallV
        ADR     r1, upcall_handler
        MOV     r2, r12
        SWI     XOS_Release

        Pull    "r0-r2, pc"


upcall_handler
  [ MEDIA_SEARCH = 0

        ; fast reject code
        TEQ     r0, #UpCall_MediaNotPresent
        TEQNE   r0, #UpCall_MediaNotKnown
        TEQNE   r0, #UpCall_ModifyingFile
        TEQNE   r0, #UpCall_MediaSearchEnd
        MOVNE   pc, r14

        TEQ     r0, #UpCall_ModifyingFile
        BEQ     upcall_handler_modifying_file

        TEQ     r0, #UpCall_MediaSearchEnd
        BEQ     upcall_handler_media_search_end

        ; fall through

upcall_handler_media_search
        Push    r14

        LDR     r14, [r12, #Flags]
        ORR     r14, r14, #Flag_MediaSearch
        STR     r14, [r12, #Flags]

        ;SWI    OS_WriteS
        ;DCB    4, 30, "meeja search start", 0
        ;ALIGN

        Pull    pc

upcall_handler_media_search_end
        Push    r14

        LDR     r14, [r12, #Flags]
        BIC     r14, r14, #Flag_MediaSearch
        STR     r14, [r12, #Flags]

        ;SWI    OS_WriteS
        ;DCB    4, 30, "meeja search end", 0
        ;ALIGN

        Pull    pc

  |

        TEQ     r0, #UpCall_ModifyingFile
        MOVNE   pc, r14

  ]

upcall_handler_modifying_file
        ; R8 = FS information word
        ; R9 = reason code

        TEQ     r9, #UpCall_ModifyingFile_Save
        TEQNE   r9, #UpCall_ModifyingFile_SetInfo
        TEQNE   r9, #UpCall_ModifyingFile_SetLoad
        TEQNE   r9, #UpCall_ModifyingFile_SetExec
        TEQNE   r9, #UpCall_ModifyingFile_SetAttr
        TEQNE   r9, #UpCall_ModifyingFile_Delete
        TEQNE   r9, #UpCall_ModifyingFile_Create
        TEQNE   r9, #UpCall_ModifyingFile_Rename
        MOVNE   pc, r14

        ; R1 -> object name
        ; R6 -> special field (or 0)

        Push    "r0-r8, r14"

        MOV     r6, r1

        MOV     r0, #33                         ; fsno -> name
        AND     r1, r8, #&FF                    ; fs number
        ADD     r2, r12, #Upcall_Filename
        MOV     r3, #256
        SWI     XOS_FSControl
        Pull    "r0-r8, pc", VS                 ; error - exit

        SUB     r2, r2, #1
0
        LDRB    r0, [r2, #1]!
        TEQ     r0, #0
        BNE     %B0
        ; R2 -> terminator

        MOV     r0, #':'                        ; add fs colon
        STRB    r0, [r2], #1

        MOV     r1, r6
        MOV     r3, #0                          ; no leaf found yet
0
        LDRB    r0, [r1], #1
        TEQ     r0, #'.'                        ; potential leafname
        MOVEQ   r3, r2                          ; leaf starts here
        STRB    r0, [r2], #1
        TEQ     r0, #0
        BNE     %B0
        ; R3 -> char before leaf, or 0

        TEQ     r3, #0                          ; did we find a leaf?
        Pull    "r0-r8, pc", EQ                 ; no - exit

        MOV     r0, #0
        STRB    r0, [r3], #1                    ; terminate path
        ; R3 -> leafname, or 0

        ; Find the display
        ;

;       SWI     1
;       DCB     4,30,"file modified...",13,10,0
;       ALIGN

        LDR     r7, [r12, #Display_First]
each_display
        TEQ     r7, #0
        Pull    "r0-r8, pc", EQ                 ; not found - exit

        ADD     r1, r7, #Display_Path
        ADD     r2, r12, #Upcall_Filename       ; path
        BL      stricmp

        LDRNE   r7, [r7, #Display_Next]
        BNE     each_display

;       SWI     1
;       DCB     "found display",13,10,0
;       ALIGN

        ; Find the icon, and delete it
        ;

  [ HASHING <> 0
        ; ### icon may be in one of n chains
  ]

        MOV     r0, #0
        LDR     r8, [r7, #Display_FirstIcon]
each_icon
        TEQ     r8, #0
        Pull    "r0-r8, pc", EQ                 ; not found - exit

        ADD     r1, r8, #Icon_Leafname
        MOV     r2, r3                          ; leaf
        BL      stricmp

        MOVNE   r0, r8                          ; last block
        LDRNE   r8, [r8, #Icon_Next]
        BNE     each_icon

;       SWI     1
;       DCB     "found icon",13,10,0
;       ALIGN

        TEQ     r0, #0                          ; last block was start of chain?
        LDR     r14, [r8, #Icon_Next]
        STREQ   r14, [r7, #Display_FirstIcon]
        STRNE   r14, [r0, #Icon_Next]
        MOV     r0, r8
        BL      heap_release                    ; needs R0
        BLVC    delete_thumbnail                ; needs R8

;       Pull    "r0-r8, pc", VC
;
;       SWI     1
;       DCB     "there was han herror",13,10,0
;       ALIGN

        Pull    "r0-r8, pc"

  ]

        END
