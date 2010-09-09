; Sprite cache area management

        GET     Hdr.Debug
        GET     Hdr.Flags
        GET     Hdr.Options
        GET     Hdr.Symbols
        GET     Hdr.Workspace

        IMPORT  stricmp

        EXPORT  sprcache_create
        EXPORT  sprcache_delete
        EXPORT  sprcache_resize
        EXPORT  sprcache_shrink

        AREA    |sprcache_code|, CODE, READONLY


sprcache_create
        ; Purpose: Create the sprite cache

        ; Since the sprite cache cannot be completely removed (see below),
        ; we search for a previous incarnation's old sprite cache and use
        ; that if available.

        STMFD   r13!, {r0-r8, r14}

        ; Look for an exisiting sprite cache area
        MOV     r1, #-1                         ; start
sprcache_search
        MOV     r0, #3                          ; enumerate areas
        SWI     XOS_DynamicArea
        CMP     r1, #-1
        BEQ     sprcache_create_new             ; no more: create new area

        MOV     r0, #2
        SWI     XOS_DynamicArea                 ; return information on area
        MOV     r4, r1                          ; preserve area no.
        ADR     r1, sprcache_name
        MOV     r2, r8
        BL      stricmp
        MOV     r1, r4                          ; restore area no.
        BNE     sprcache_search

        B       sprcache_create_store

sprcache_create_new

        ; Create a new sprite cache area
        MOV     r0, #0
        MOV     r1, #-1
        MOV     r2, #1<<12                      ; initial size of area - 4Kb
        MOV     r3, #-1                         ; base of area
        MOV     r4, #1<<7                       ; flags
        MOV     r5, #1<<24                      ; max size - 16Mb
        MOV     r6, #0                          ; handler
        MOV     r7, #0                          ; wksp for handler
        ADR     r8, sprcache_name               ; name of area
        SWI     XOS_DynamicArea
        LDMVSFD r13!, {r0-r8, pc}

sprcache_create_store

        ; Store the sprite cache area details
        STR     r3, [r12, #Sprites_Base]
        STR     r1, [r12, #Sprites_Handle]

        ; Initialise sprite cache area
        MOV     r0, r3
        BL      clearcache

        LDMFD   r13!, {r0-r8, pc}

sprcache_name
        DCB     "PhotoFiler sprites", 0
        ALIGN


sprcache_delete
        ; Purpose: Delete the sprite cache

        ; The sprite cache cannot be completely removed, since at the time
        ; of exit directory displays may still reference it as their sprite
        ; area.

        ; For this reason, the dynamic area is not deleted, but resized to
        ; 4K and cleared.

        STMFD	r13!, {r0-r1, r14}

        ; Resize sprite cache to 4K
        LDR     r0, [r12, #Sprites_Base]
        LDR     r1, [r0, #0]
        SUB     r1, r1, #1<<12
        RSB     r1, r1, #0
        BL      sprcache_resize
        LDMVSFD	r13!, {r0-r1, pc}

        ; Clear sprite cache area
        ; R0 -> base
        BL      clearcache

        LDMFD	r13!, {r0-r1, pc}


sprcache_resize
        ; Purpose: Change the size of the sprite cache
        ; Entry:   R1 = size change (signed)

        STMFD	r13!, {r0-r2, r14}

        LDR     r0, [r12, #Sprites_Handle]
        MOV     r2, r1                          ; preserve size change
        SWI     XOS_ChangeDynamicArea
        LDMVSFD	r13!, {r0-r2, pc}

        LDR     r0, [r12, #Sprites_Base]
        CMP     r2, #0                          ; adjust the size change
        RSBLT   r1, r1, #0                      ; fix R1 to be actual change
        LDRNE   r2, [r0, #0]
        ADDNE   r2, r2, r1
        STRNE   r2, [r0, #0]

        LDMFD	r13!, {r0-r2, pc}


sprcache_shrink
        STMFD	r13!, {r0-r1, r14}

        LDR     r1, [r12, #Sprites_Base]
        LDR     r0, [r1, #12]                   ; first free word
        ADD     r0, r0, #4                      ; want at least one free word
        LDR     r1, [r1, #0]                    ; size of area
        SUB     r1, r0, r1                      ; i.e. -ve result
        CMP     r1, #-4096                      ; if there's one page free,
        BLLE    sprcache_resize                 ;  then shrink

        LDMFD	r13!, {r0-r1, pc}


clearcache
        STMFD	r13!, {r0-r3, r14}

        MOV     r1, #1<<12                      ; size of area - 4Kb
        MOV     r2, #0
        MOV     r3, #16
        MOV     r14, #16
        STMIA   r0, {r1-r3, r14}

        LDMFD	r13!, {r0-r3, pc}


        END
