; ---------------------------------------------------------------------------
;    Name: PhotoFiler
; Purpose: Allows the Filer to thumbnail images, plus other bits
;  Author: © David Thomas, 1998-2020. Based on JFFilerPro, © Justin Fletcher.
;    Date: 2.10 (12 Jun 2020)
; ---------------------------------------------------------------------------

        GET     Hdr.Debug
        GET     Hdr.Flags
        GET     Hdr.Macros
        GET     Hdr.Options
        GET     Hdr.Symbols
        GET     Hdr.Workspace

        IMPORT  heap_create
        IMPORT  heap_delete

        IMPORT  sprcache_create
        IMPORT  sprcache_delete

  [ UPCALL_HANDLER <> 0
        IMPORT  upcall_on
        IMPORT  upcall_off
  ]

        IMPORT  wimp_createwindow_pre
        IMPORT  wimp_createwindow_post
        IMPORT  wimp_deletewindow_pre
        IMPORT  wimp_ploticon_pre
        IMPORT  wimp_ploticon_post
        IMPORT  wimp_prefilter
        IMPORT  wimp_postfilter
        IMPORT  wimp_redrawwindow_pre
        IMPORT  wimp_updatewindow_pre

        IMPORT  strcpy

        AREA    |!photofiler_code|, CODE, READONLY


        ENTRY

; ---------------------------------------------------------------------------

        DCD     0                               ; start code
        DCD     module_initialise               ; initialisation code
        DCD     module_finalise                 ; finalisation code
        DCD     module_service                  ; service call handler
        DCD     module_title                    ; title string
        DCD     module_help                     ; help string
        DCD     module_commands                 ; help, command keyword table
        DCD     0                               ; SWI base number
        DCD     0                               ; SWI handler
        DCD     0                               ; SWI decode table
        DCD     0                               ; SWI decode code
        DCD     0                               ; MessageTrans file
        DCD     module_flags                    ; flags

module_flags
        DCD     1                               ; 32-bit compatible

; ---------------------------------------------------------------------------

module_title
        DCB     "PhotoFiler", 0

module_help
        DCB     "PhotoFiler", 9, "2.10 (12 Jun 2020)"
        DCB     " © David Thomas, 1998-2020", 0
        ALIGN

; ---------------------------------------------------------------------------

module_commands
  [ DUMP_COMMAND <> 0
        DCB     "PhotoFilerShow", 0
        ALIGN
        DCD     command_show
        DCD     &00000000
        DCD     show_workspace_syntax
        DCD     show_workspace_help
  ]

        DCB     "PhotoFilerIgnore", 0
        ALIGN
        DCD     command_fsreject
        DCD     &00010001
        DCD     fsreject_syntax
        DCD     fsreject_help

        DCD     0                               ; end of list

        ;
        ; Command code
        ;
        ; Preserve R7-R11.
        ; Set V if error.
        ;


  [ DUMP_COMMAND <> 0
command_show
        Push    "r7-r8, r14"
        LDR     r12, [r12]
        SWI     OS_WriteI + 4
        LDR     r7, [r12, #Display_First]
show_workspace_winloop
        TEQ     r7, #0
        Pull    "r7-r8, pc", EQ
        ADD     r0, r7, #Display_Path           ; directory path
        SWI     OS_Write0
        SWI     OS_WriteI + ','
        SWI     OS_WriteI + ' '
        LDR     r0, [r7, #Display_Handle]       ; handle
        BL      show_r0
        SWI     OS_NewLine                      ; newline
        LDR     r8, [r7, #Display_FirstIcon]
show_workspace_iconloop
        TEQ     r8, #0
        LDREQ   r7, [r7, #Display_Next]
        BEQ     show_workspace_winloop
        SWI     OS_WriteI + ' '
        ADD     r0, r8, #Icon_Leafname          ; leafname
        SWI     OS_Write0
        SWI     OS_WriteI + ','
        SWI     OS_WriteI + ' '
        LDR     r0, [r8, #Icon_FileType]        ; file type
        BL      show_r0
        SWI     OS_WriteI + ','
        SWI     OS_WriteI + ' '
        ADD     r0, r8, #Icon_Validation        ; sprite
        SWI     OS_Write0
        SWI     OS_WriteI + ','
        SWI     OS_WriteI + ' '
        LDR     r0, [r8, #Icon_SpriteArea]      ; sprite area
        BL      show_r0
        SWI     OS_NewLine
        LDR     r8, [r8, #Icon_Next]
        B       show_workspace_iconloop

show_r0
        Push    "r0-r2, r14"
        ADD     r1, r12, #Scratch
        MOV     r2, #12
        SWI     XOS_ConvertHex8
        SWI     OS_Write0
        Pull    "r0-r2, pc"

show_workspace_help
        DCB     "*PhotoFilerShow displays the contents of PhotoFiler‘s works"
        DCB     "pace.", 13, 10
show_workspace_syntax
        DCB     "Syntax: *PhotoFilerShow", 0
        ALIGN
  ]

command_fsreject
        Push    "r14"

        LDR     r12, [r12]

        MOV     r1, r0                          ; keep command tail

        MOV     r0, #6                          ; claim workspace
        MOV     r3, #sizeof_fsreject
        SWI     XOS_Module
        Pull    "pc", VS

        LDR     r14, [r12, #FSReject_First]     ; link into start of chain
        STR     r14, [r2, #FSReject_Next]
        STR     r2, [r12, #FSReject_First]

        ; R1 -> command tail
        ADD     r2, r2, #FSReject_Wildcard
        BL      strcpy

        Pull    "pc"

fsreject_help
        DCB     "*PhotoFilerIgnore adds to the list of directories not to th"
        DCB     "umbnail.", 13, 10
fsreject_syntax
        DCB     "Syntax: *PhotoFilerIgnore <wildcarded string>", 0
        ALIGN

; ---------------------------------------------------------------------------

module_service_table
        DCD     0                               ; flags
        DCD     module_service_entry            ; address of handler
        DCD     Service_StartedFiler            ; calls of interest
        DCD     Service_FilerDying
        DCD     Service_FilterManagerInstalled
        DCD     Service_FilterManagerDying
        DCD     0                               ; terminator
module_service_table_address
        DCD     module_service_table
module_service
        MOV     r0, r0                          ; magic word
        TEQ     r1, #Service_StartedFiler
        TEQNE   r1, #Service_FilerDying
        TEQNE   r1, #Service_FilterManagerInstalled
        TEQNE   r1, #Service_FilterManagerDying
        MOVNE   pc, r14

module_service_entry
        ;
        ; This is A Bit Crap, because module init/fin entry points don't have
        ; to preserve a lot of registers. Service call handler has to.
        ;
        ; there may also be re-entrancy issues here. bum.
        ;

        TEQ     r1, #Service_FilerDying
        TEQNE   r1, #Service_FilterManagerDying
        BEQ     %F0
        Push    "r0, r2-r8, r14"
        BL      module_initialise
        Pull    "r0, r2-r8, pc"
0
        Push    "r0, r2-r8, r14"
        BL      module_finalise
        Pull    "r0, r2-r8, pc"


module_initialise
        ;
        ; Module initialisation code
        ;
        ; Must preserve mode, interrupt state, R7-R11 and R13.
        ; V set if error, clear otherwise.
        ;

        Push "r14"

        DBSET   DebugOn :OR: UseTracker
        DBF     "\fPhotoFiler initialising\n"

        ; Check we're not already initialised
        ;

        LDR     r2, [r12]
        TEQ     r2, #0
        BNE     %FT99

        ; Claim workspace
        ;

        MOV     r0, #6
        MOV     r3, #sizeof_workspace
        SWI     XOS_Module
        BVS     %FT99

        STR     r2, [r12]
        MOV     r12, r2

        ; Clear the workspace
        ;

        MOV     r0, #0
        MOV     r1, #0
00
        STR     r0, [r12, r1]
        ADD     r1, r1, #4
        CMP     r1, r3
        BLT     %BT00

        ; Set default options
        ;

        MOV     r0, #172                        ; sizes
        MOV     r1, #74
        MOV     r2, #10                         ; timeslice in cs
        ADD     r3, r12, #4
        STMIA   r3, {r0-r2}
  [ ARTWORKS <> 0
        MOV     r0, #100                        ; ArtWorks quality
        STR     r0, [r12, #ArtWorks_Quality]
  ]

        ; Initialise
        ;

        BL      heap_create
        BL      sprcache_create
        BL      filters_on
  [ UPCALL_HANDLER <> 0
        BL      upcall_on
  ]

99
        Pull pc


module_finalise
        ;
        ; Module finalisation code
        ;
        ; Must preserve mode, interrupt state, R7-R11 and R13.
        ; V set if error, clear otherwise.
        ;
        Push    "r14"

        ; Check we're not already finalised
        ;

        LDR     r14, [r12]
        TEQ     r14, #0
        BEQ     %FT99

        ; Keep private word address for clearing later
        ;

        MOV     r3, r12

        LDR     r12, [r12]

        ; Finalise
        ;

  [ UPCALL_HANDLER <> 0
        BL      upcall_off
  ]
        BL      filters_off
        BL      sprcache_delete
        BL      heap_delete

        ; Release workspace
        ;

        MOV     r2, r12
        MOV     r0, #7
        SWI     XOS_Module

        ; Clear private word
        ;

        MOV     r0, #0
        STR     r0, [r3]

99
        Pull    "pc"


; Filters -------------------------------------------------------------------

filters_on
        Push    "r0-r4, r14"

        ; Determine the Filer's task handle (the subject-to-change way)
        MOV     r0, #18
        ADR     r1, filer
        SWI     XOS_Module
        LDR     r3, [r4]                        ; get task handle from p.word
        STR     r3, [r12, #Filer_TaskHandle]

        ; Install Filer filters
        ADRL    r0, module_title
        ADRL    r1, wimp_prefilter
        MOV     r2, r12
        ;LDR    r3, [r12, #Filer_TaskHandle]
        SWI     XFilter_RegisterPreFilter
        ;ADR    r0, module_title
        ADRL    r1, wimp_postfilter
        ;MOV    r2, r12
        ;LDR    r3, [r12, #Filer_TaskHandle]
        MOV     r4, #&FFFFFFFE
        SWI     XFilter_RegisterPostFilter

        ; Install Wimp filters
        LDR     r0, wswi
        MOV     r2, r12
        MOV     r1, #Wimp_CreateWindow - Wimp_SWIBase
        ORR     r1, r1, #1<<31
        ADRL    r3, wimp_createwindow_pre
        ADRL    r4, wimp_createwindow_post
        SWI     XWimp_RegisterFilter
        MOV     r1, #Wimp_DeleteWindow - Wimp_SWIBase
        ORR     r1, r1, #1<<31
        ADRL    r3, wimp_deletewindow_pre
        MOV     r4, #0
        SWI     XWimp_RegisterFilter
        MOV     r1, #Wimp_RedrawWindow - Wimp_SWIBase
        ORR     r1, r1, #1<<31
        ADRL    r3, wimp_redrawwindow_pre
        ;MOV     r4, #0
        SWI     XWimp_RegisterFilter
        MOV     r1, #Wimp_UpdateWindow - Wimp_SWIBase
        ORR     r1, r1, #1<<31
        ADRL    r3, wimp_updatewindow_pre
        ;MOV     r4, #0
        SWI     XWimp_RegisterFilter
        MOV     r1, #Wimp_PlotIcon - Wimp_SWIBase
        ORR     r1, r1, #1<<31
        ADRL    r3, wimp_ploticon_pre
        ADRL    r4, wimp_ploticon_post
        SWI     XWimp_RegisterFilter

        Pull    "r0-r4, pc"

filters_off
        Push    "r0-r4, r14"

        LDR     r0, wswi
        MOV     r2, r12
        MOV     r1, #Wimp_CreateWindow - Wimp_SWIBase
        ADRL    r3, wimp_createwindow_pre
        ADRL    r4, wimp_createwindow_post
        SWI     XWimp_RegisterFilter
        MOV     r1, #Wimp_DeleteWindow - Wimp_SWIBase
        ADRL    r3, wimp_deletewindow_pre
        MOV     r4, #0
        SWI     XWimp_RegisterFilter
        MOV     r1, #Wimp_RedrawWindow - Wimp_SWIBase
        ADRL    r3, wimp_redrawwindow_pre
        ;MOV     r4, #0
        SWI     XWimp_RegisterFilter
        MOV     r1, #Wimp_UpdateWindow - Wimp_SWIBase
        ADRL    r3, wimp_updatewindow_pre
        ;MOV     r4, #0
        SWI     XWimp_RegisterFilter
        MOV     r1, #Wimp_PlotIcon - Wimp_SWIBase
        ADRL    r3, wimp_ploticon_pre
        ADRL    r4, wimp_ploticon_post
        SWI     XWimp_RegisterFilter

        ; Remove Filer filters
        ADRL    r0, module_title
        ADRL    r1, wimp_prefilter
        MOV     r2, r12
        LDR     r3, [r12, #Filer_TaskHandle]
        SWI     XFilter_DeRegisterPreFilter
        ;ADR    r0, module_title
        ADRL    r1, wimp_postfilter
        ;MOV    r2, r12
        ;LDR    r3, [r12, #Filer_TaskHandle]
        MOV     r4, #&FFFFFFFE
        SWI     XFilter_DeRegisterPostFilter

        Pull    "r0-r4, pc"

wswi
        DCB     "WSWI"

filer
        DCB     "Filer", 0
        ALIGN


        END
