; Dynamic area workspace heap management

        GET     Hdr.Debug
        GET     Hdr.Flags
        GET     Hdr.Macros
        GET     Hdr.Options
        GET     Hdr.Symbols
        GET     Hdr.Workspace

        IMPORT  shrink_need

        EXPORT  heap_claim
        EXPORT  heap_create
        EXPORT  heap_delete
        EXPORT  heap_release
        EXPORT  heap_resize
        EXPORT  heap_shrink

        AREA    |heap_code|, CODE, READONLY


heap_create
        ; Purpose: Creates a heap in a dynamic area.

        Push    "r0-r8, r14"

        MOV     r0, #0                          ; create dynamic area
        MOV     r1, #-1                         ; allocate area number
        MOV     r2, #1<<12                      ; base size - 4Kb
        MOV     r3, #-1                         ; base of area
        MOV     r4, #1<<7                       ; green bar
        MOV     r5, #1<<24                      ; max size - 16Mb
        MOV     r6, #0                          ; no handler routine
        MOV     r7, #0                          ; workspace for handler
        ADR     r8, heap_name                   ; name of heap
        SWI     XOS_DynamicArea
        BVS     exit

        STR     r1, [r12, #Heap_Handle]         ; allocated area number
        STR     r3, [r12, #Heap_Base]           ; -> area

        MOV     r0, #0                          ; initialise heap
        MOV     r1, r3                          ; -> heap
        MOV     r3, #1<<12                      ; size of heap - 4Kb
        SWI     XOS_Heap

exit
        Pull    "r0-r8, pc"

heap_name
        DCB     "PhotoFiler workspace", 0
        ALIGN


heap_delete
        ; Purpose: Deletes the heap.

        Push    "r0-r1, r14"

        MOV     r0, #1                          ; delete dynamic area
        LDR     r1, [r12, #Heap_Handle]
        SWI     XOS_DynamicArea

        Pull    "r0-r1, pc"


heap_claim
        ; Purpose: Claims a block of memory from the heap.
        ; Entry:   R0 = required size (bytes)
        ; Exit:    R0 = pointer to block, or VS if claim failed

        Push    "r1-r4, r14"

        DBF     "heap_claim(%0w)\n"

        TEQ     r0, #0                          ; request for no bytes
        BEQ     heap_claim_failed

        MOV     r4, r0                          ; preserve size
claim
        MOV     r3, r4                          ; bytes to claim
        LDR     r1, [r12, #Heap_Base]
        MOV     r0, #2                          ; claim heap block
        SWI     XOS_Heap
        TEQ     r2, #0                          ; 0 returned even if V set
        MOVNE   r0, r2                          ; address of block
        BNE     %FT99                           ; success

        MOV     r1, r3
        LDR     r0, [r12, #Heap_Handle]         ; extend the heap area
        SWI     XOS_ChangeDynamicArea
        BVS     %FT99

        MOV     r3, r1                          ; actual size change
        LDR     r1, [r12, #Heap_Base]
        MOV     r0, #5                          ; change size of heap
        SWI     XOS_Heap
        BVS     %FT99

        B       claim

heap_claim_failed
        ; ### this won't set up R0 -> errblk
        MSR     cpsr_f, #1<<28                  ; set V

99
        Pull    "r1-r4, pc"


heap_resize
        ; Purpose: Resizes a heap block.
        ; Entry:   R0 = pointer to block
        ;          R1 = size increase (+ve) or decrease (-ve)
        ; Exit:    R0 = pointer to (possibly moved) block

        Push    "r1-r5, r14"

        DBF     "heap_resize(%0w, %1w)\n"

        CMP     r1, #0
        BLT     heap_resize_shrink

heap_resize_grow
        DBF     "grow\n"

        DBF     "block pointer r0 is %0w\n"
        DBF     "size change r1 is %1w\n"

        MOV     r5, r1                          ; keep size change
        MOV     r4, r0                          ; keep block pointer

heap_resize_try_grow
        DBF     "try claim\n"

        MOV     r3, r5
        MOV     r2, r4
        LDR     r1, [r12, #Heap_Base]
        MOV     r0, #4
        SWI     XOS_Heap
        MOVVC   r0, r2                          ; set for exit
        BVC     %FT99

        DBF     "must grow heap\n"

        DBF     "r3 is %3w\n"

        MOV     r1, r3
        LDR     r0, [r12, #Heap_Handle]         ; extend the heap area
        SWI     XOS_ChangeDynamicArea
        BVS     %FT99

        MOV     r3, r1                          ; actual size change
        LDR     r1, [r12, #Heap_Base]
        MOV     r0, #5                          ; change size of heap
        SWI     XOS_Heap
        BVS     %FT99

        DBF     "try again\n"

        B       heap_resize_try_grow

heap_resize_shrink
        DBF     "shrink\n"

        MOV     r3, r1
        MOV     r2, r0
        LDR     r1, [r12, #Heap_Base]
        MOV     r0, #4
        SWI     XOS_Heap
        MOV     r0, r2                          ; set for exit

        BL      shrink_need

99
        ;DEBUGEB

        DBF     "EXIT heap_resize\n"

        Pull    "r1-r5, pc"


heap_release
        ; Purpose: Releases a block of memory from the heap.
        ; Entry:   R0 = pointer to block

        Push    "r0-r2, r14"

        BL      shrink_need

        MOV     r2, r0                          ; -> block
        LDR     r1, [r12, #Heap_Base]           ; -> heap
        MOV     r0, #3                          ; release heap block
        SWI     XOS_Heap

        Pull    "r0-r2, pc"


heap_shrink
        Push    "r0-r3, r14"

        ; OS_Heap's describe reason code causes corruption! :-(

        MOV     r3, #&80000000                  ; shrink as much as possible
        LDR     r1, [r12, #Heap_Base]           ; -> heap
        MOV     r0, #5                          ; change size of heap
        SWI     XOS_Heap                        ; expect VS here
        ; R3 = actual change in size
        RSB     r1, r3, #0                      ; change da size
        LDR     r0, [r12, #Heap_Handle]
        SWI     XOS_ChangeDynamicArea
        ; ### do i care about errors here?

        ; Add difference back into heap
        SUB     r3, r3, r1                      ; difference
        LDR     r1, [r12, #Heap_Base]           ; -> heap
        MOV     r0, #5                          ; change size of heap
        SWI     XOS_Heap

        Pull    "r0-r3, pc"


        END
