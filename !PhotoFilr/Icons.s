; Icon block handling

        GET     Hdr.Debug
        GET     Hdr.Flags
        GET     Hdr.Options
        GET     Hdr.Symbols
        GET     Hdr.Workspace

        IMPORT  heap_claim
        IMPORT  stricmp
        IMPORT  strcpy

        EXPORT  find_icon
        EXPORT  add_icon

        AREA    |icons_code|, CODE, READONLY


  [ HASHING <> 0

        ; Entry: R1 -> leafname
        ; Exit : R0 = array index
hash
        Enter   "r2-r4"

        MOV     r0, #0                          ; hash value
        MOV     r2, #0                          ; string index
        LDRB    r3, [r1, r2]
        ;TEQ    r3, #0
        ;BEQ    hash_done
hash_loop
        ADD     r4, r0, r0, LSL #2              ; multiply by 37
        ADD     r0, r4, r0, LSL #5
        ADD     r0, r0, r3                      ; add to hash
        ADD     r2, r2, #1
        LDRB    r3, [r1, r2]
        TEQ     r3, #0
        BNE     hash_loop
;hash_done
        AND     r0, r0, #31                     ; 0 - 31
        ; R0 = hashed value
        Exit    "r2-r4"

  ]


find_icon
        ; Entry: R1 -> leafname
        ;        R7 -> display block
        ; Exit:  R8 -> icon block, or 0
        ;        EQ if the icon exists, NE otherwise

        STMFD   r13!, {r2, r14}

  [ HASHING <> 0
        ; ### Remember to stack R0 too if HASHING is on
        BL      hash
        ADD     r14, r7, #Display_Icons
        LDR     r8, [r14, r0, LSL #2]
  |
        LDR     r8, [r7, #Display_FirstIcon]
  ]

00
        TEQ     r8, #0
        BEQ     not_found

        ADD     r2, r8, #Icon_Leafname
        BL      stricmp
        BEQ     %FT99                           ; found: return EQ

        LDR     r8, [r8, #Icon_Next]
        B       %BT00

not_found
        TEQ     pc, #0                          ; set nz..
                                                ; not found: return NE
99
        LDMFD   r13!, {r2, pc}


add_icon

        ; Adds a new thumbnail block

        ; Entry: R1 -> leafname
        ;        R2 = file type
        ;        R3 = flags
        ;        R7 -> display block
        ; Exit:  R8 -> icon block
        ;        or VS if failed

        STMFD   r13!, {r0-r7, r14}

        MOV     r0, #sizeof_icon                ; claim memory
        BL      heap_claim
        LDMVSFD r13!, {r0-r7, pc}               ; return with flags

        MOV     r8, r0                          ; new icon block

        ; Add the thumbnail block to the end of the chain
        ;

  [ HASHING <> 0
        BL      hash
        ADD     r14, r7, #Display_Icons
        ADD     r14, r14, r0, LSL #2
        LDR     r0, [r14]
        TEQ     r0, #0
        STREQ   r8, [r14]                       ; start of chain
  |
        LDR     r0, [r7, #Display_FirstIcon]
        TEQ     r0, #0
        STREQ   r8, [r7, #Display_FirstIcon]    ; start of chain
  ]
        BEQ     done
next
        LDR     r14, [r0, #Icon_Next]
        TEQ     r14, #0
        MOVNE   r0, r14
        BNE     next
        STR     r8, [r0, #Icon_Next]
done
        MOV     r0, #0
        STR     r0, [r8, #Icon_Next]            ; end of chain

        STR     r2, [r8, #Icon_FileType]        ; store file type
        STR     r3, [r8, #Icon_Flags]           ; store flags

        ; R2,R3 now free

        ; R1 -> leafname
        ADD     r2, r8, #Icon_Leafname          ; copy leafname
        BL      strcpy

        ; R1 now free

        ; Construct an 'Swait_xxx' string
        ;

        ADR     r1, wait
        LDMIA   r1, {r0, r2}
        ADD     r1, r8, #Icon_Validation
        STMIA   r1!, {r0, r2}
        SUB     r1, r1, #3                      ; back a bit
        LDR     r0, [r8, #Icon_FileType]        ; get the file type again
        ; R1 setup
        MOV     r2, #5                          ; size of buffer in R2
        SWI     XOS_ConvertHex4

        MOV     r0, #'_'
        STRB    r0, [r1, #-4]                   ; overwrite first hex char

        MOV     r0, #Icon_Make                  ; thumbnail needs making
        STR     r0, [r8, #Icon_SpriteArea]

        ADD     r0, r12, #Icon_Block            ; update bbox (expects
        LDMIA   r0, {r1-r4}                     ; Icon_Block to be set up)
        ADD     r0, r8, #Icon_x0
        STMIA   r0, {r1-r4}

        LDR     r14, [r12, #Flags]              ; force an update if needed
        TST     r14, #Flag_NeedUpdate
        ORREQ   r14, r14, #Flag_NeedUpdate
        STREQ   r14, [r12, #Flags]

        LDMFD   r13!, {r0-r7, pc}

wait
        DCB     "Swait"
        ALIGN

        END
