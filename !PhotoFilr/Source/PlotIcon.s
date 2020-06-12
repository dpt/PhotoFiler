; Wrappers for Wimp_PlotIcon

        GET     Hdr.Debug
        GET     Hdr.Flags
        GET     Hdr.Macros
        GET     Hdr.Options
        GET     Hdr.Symbols
        GET     Hdr.Workspace

        IMPORT  add_icon
        IMPORT  find_display
        IMPORT  find_icon
        IMPORT  strin
        IMPORT  strncpy
        IMPORT  filer_active

        EXPORT  wimp_ploticon_pre
        EXPORT  wimp_ploticon_post

        AREA    |ploticon_code|, CODE, READONLY


wimp_ploticon_pre
        ; Purpose: Called before Wimp_PlotIcon acts.

        ; Save PlotIcon's icon block pointer (restored in post filter)
        ;
        STR     r1, [r12, #PlotIcon]

        Push    r14

        BL      filer_active
        Pull    pc, NE                          ; filer is not active

  [ MEDIA_SEARCH <> 0
        LDR     r14, [r12, #Flags]
        TST     r14, #Flag_MediaSearch          ; is a media search going on?
        Pull    pc, NE                          ; yes - exit
  ]

        Pull    r14

        Push    "r0-r8, r14"

        ; Locate the display block for the current window
        ;
        BL      find_display
        BNE     wimp_ploticon_pre_ignore        ; unknown
        ; R7 updated with current window block

        ; Save PlotIcon's block for use later
        ;
        LDMIA   r1, {r0-r6, r8}
        ADD     r14, r12, #Icon_Block
        STMIA   r14, {r0-r6, r8}

        ; Locate the icon block for this file (if any)
        ; Expects: R1 -> leafname, R7 -> display block
        LDR     r1, [r12, #Icon_Block + 20]     ; R1 -> leafname
        BL      find_icon
        ; R8 updated (as are flags) with icon block

        BEQ     known

unknown
        ; Examine the leaf name. If it contains a dot, assume that there was
        ; an ellipsis present.

        ; R1 -> leafname

00
        LDRB    r0, [r1], #1
        TEQ     r0, #'.'
        BEQ     wimp_ploticon_pre_ignore        ; dot - exit
        CMP     r0, #' '                        ; not zero terminated
        BGT     %BT00

        ; Examine the file type
        ;

        ; '!app'
        ; 'application'
        ; 'directory'
        ; 'directoryo'
        ; 'file_xxx'
        ; 'sm!app'
        ; 'small_app'
        ; 'small_dir'
        ; 'small_diro'
        ; 'small_xxx'

        ; Check for 'S' or 's', indicating a sprite
        ;

        ; R6 -> validation string
        LDRB    r0, [r6], #1
        TEQ     r0, #'S'
        TEQNE   r0, #'s'
        BNE     wimp_ploticon_pre_ignore        ; no sprite - exit

        LDRB    r0, [r6]
        TEQ     r0, #'f'                        ; "file_..."
        ADDEQ   r6, r6, #5
        BEQ     file

        TEQ     r0, #'d'                        ; "directory", "directoryo"
        TEQNE   r0, #'a'                        ; "application"
        TEQNE   r0, #'!'                        ; "!app"
        BEQ     directory

        ; Have now eliminated all non 'small' or 'sm!' types

        LDRB    r0, [r6, #2]
        TEQ     r0, #'!'
        BEQ     directory                       ; "sm!app"

        LDRB    r0, [r6, #6]
        LDRB    r1, [r6, #7]
        LDRB    r2, [r6, #8]

        TEQ     r0, #'d'
        TEQEQ   r1, #'i'
        TEQEQ   r2, #'r'
        BEQ     directory                       ; "small_dir", "small_diro"

        TEQ     r0, #'a'
        TEQEQ   r1, #'p'
        TEQEQ   r2, #'p'
        BEQ     directory                       ; "small_app"

        ; Fall-through for 'small_...'
        ;

        ADD     r6, r6, #6

file
        ; R6 -> text file type (including "lxa", "unf", etc)

        ; Decode hex value into file type
        ;

        MOV     r0, #16                         ; hex
        MOV     r1, r6
        SWI     XOS_ReadUnsigned
        BVS     wimp_ploticon_pre_ignore        ; bad hex (lxa, unf) - exit
        ; R2 = file type

        EOR     r14, r2, #&F00
        TEQ     r14, #&F9
        BEQ     do_sprite

        EOR     r14, r2, #&C00
        TEQ     r14, #&85
        BEQ     do_jpeg

        EOR     r14, r2, #&A00
        TEQ     r14, #&FF
        BEQ     do_drawfile

  [ ARTWORKS <> 0
        EOR     r14, r2, #&D00
        TEQ     r14, #&94
        BEQ     do_artworks
  ]

        ; It's a file which is something other than Sprite, JPEG or DrawFile.
        ; If ImageFS flag is set, look to see what it is.
        ;

        LDR     r0, [r12, #Flags]
        TST     r0, #Flag_IgnoreImageFS
        BNE     wimp_ploticon_pre_ignore        ; imagefs not enabled - exit

        ; ImageFS enabled

        ; Construct a filename, so we can OS_File and see if it's an image
        ; file
        ;

;       SWI     OS_WriteS
;       DCB     4,30,"in imagefs code",13,10,0
;       ALIGN

        ADD     r1, r12, #Temp_Filename
        ADD     r2, r7, #Display_Path
path    LDRB    r0, [r2], #1
        TEQ     r0, #0
        STRNEB  r0, [r1], #1                    ; don't terminate
        BNE     path
        MOV     r0, #'.'
        STRB    r0, [r1], #1
        LDR     r2, [r12, #Icon_Block + 20]     ; R1 -> leafname
leaf    LDRB    r0, [r2], #1
        TEQ     r0, #0
        STRB    r0, [r1], #1                    ; terminate
        BNE     leaf

        MOV     r0, #17
        ADD     r1, r12, #Temp_Filename
        SWI     XOS_File
        BVS     wimp_ploticon_pre_ignore        ; error
        TEQ     r0, #3
        BNE     wimp_ploticon_pre_ignore        ; not an image file

;       SWI     OS_WriteS
;       DCB     "is an image file",13,10,0
;       ALIGN

        ; test for imagefs filetypes
        ;

        MOV     r2, r2, LSL #12
        MOV     r2, r2, LSR #20
        ; R2 = file type
        ADR     r0, imagefs_types
next    LDR     r1, [r0], #4
        TEQ     r1, #&1000
        BEQ     wimp_ploticon_pre_ignore        ; no type matches
        TEQ     r1, r2
        BNE     next
        MOV     r3, #IconFlag_ImageFS           ; match
        B       add_thumbnail


imagefs_types
        ; o => obsolete file type (used by older ImageFS versions)
        ; v => vector
        ; x => not currently supported by ImageFS 2.37

        DCD     &690                            ; Clear
        DCD     &691                            ; Degas
        DCD     &692                            ; IMG
        DCD     &693                            ; AmigaIFF
        DCD     &694                            ; MacPaint
        DCD     &695                            ; GIF
;       DCD     &696                            ; OS2Met        (ovx)
        DCD     &697                            ; PCX
        DCD     &698                            ; QRT
        DCD     &699                            ; MTV
        DCD     &69C                            ; BMP
        DCD     &69D                            ; Targa
        DCD     &69E                            ; PBMPlus
        DCD     &6A2                            ; ColoRIX
        DCD     &6A5                            ; ICO
;       DCD     &6A6                            ; WPG           ( v )
;       DCD     &6F0                            ; CorelXch      (ovx)
        DCD     &6FA                            ; WinMeta       (ov )
;       DCD     &6FD                            ; CGMeta        (ovx)
;       DCD     &6FE                            ; AdobeIll      (ovx)
;;      DCD     &AFF                            ; DrawFile      ( v )
        DCD     &B1E                            ; PsionPIC
;       DCD     &B2B                            ; CGMeta        ( vx)
;       DCD     &B2C                            ; OS2Met        ( vx)
;       DCD     &B2D                            ; AdobeIll      ( vx)
;       DCD     &B2E                            ; CorelXch      ( vx)
        DCD     &B2F                            ; WinMeta       ( v )
;       DCD     &B60                            ; PNG           (  x)
;       DCD     &B61                            ; XBitMap       (  x)
;;      DCD     &C85                            ; JPEG
;       DCD     &CAE                            ; HPGL          ( v )
;       DCD     &CCF                            ; LotusPIC      ( v )
;       DCD     &DEA                            ; DXF           ( v )
        DCD     &F98                            ; PhotoShp
        DCD     &FC9                            ; SunRastr
        DCD     &FD5                            ; PICT2
        DCD     &FF0                            ; TIFF
;;      DCD     &FF9                            ; Sprite
        DCD     &1000                           ; end of list marker

do_sprite
        LDR     r0, [r12, #Flags]
        TST     r0, #Flag_ApplicationSprites
        BNE     sprites_dontcheckleaf

        Push    "r2"                    ; save file type
        LDR     r1, [r12, #Icon_Block + 20]     ; R1 -> leafname
        ADR     r2, sprites_id
        MOV     r3, #0                          ; offset
        BL      strin
        Pull    "r2"                    ; restore file type
        CMP     r0, #-1
        BNE     wimp_ploticon_pre_ignore        ; INSTR(file$,"Sprites")<>0

sprites_dontcheckleaf
        LDR     r0, [r12, #Flags]
        TST     r0, #Flag_IgnoreSprites
        ; R2 = file type
        MOVEQ   r3, #0                          ; R3 = flags
        BEQ     add_thumbnail
        B       wimp_ploticon_pre_ignore

do_jpeg
        LDR     r0, [r12, #Flags]
        TST     r0, #Flag_IgnoreJPEGs
        ; R2 = file type
        MOVEQ   r3, #0                          ; R3 = flags
        BEQ     add_thumbnail
        B       wimp_ploticon_pre_ignore

do_drawfile
        LDR     r0, [r12, #Flags]
        TST     r0, #Flag_IgnoreDrawFiles
        ; R2 = file type
        MOVEQ   r3, #0                          ; R3 = flags
        BEQ     add_thumbnail
        B       wimp_ploticon_pre_ignore

do_artworks
        LDR     r0, [r12, #Flags]
        TST     r0, #Flag_IgnoreArtWorks
        ; R2 = file type
        MOVEQ   r3, #0                          ; R3 = flags
        BEQ     add_thumbnail
        B       wimp_ploticon_pre_ignore


add_thumbnail
        ; R2 = file type
        ; R3 = flags
        ; R7 = display block

        LDR     r1, [r12, #Icon_Block + 20]     ; R1 -> leafname
        BL      add_icon
        ; R8 updated
        BVS     wimp_ploticon_pre_ignore

        B       known


directory
        ; It's a directory or application
        LDR     r14, [r12, #Icon_Block + 20]    ; text
        LDRB    r14, [r14]
        TEQ     r14, #'!'
        BEQ     dynamic_app

        ; fallthrough

dynamic_dir
        ; It's a directory
        ADD     r2, r12, #Scratch               ; sprite name string

        BL      is_it_small
        MOVEQ   r0, #'s'                        ; it's small, prefix the
        STREQB  r0, [r2], #1                    ; directory sprite name with
        MOVEQ   r0, #'m'                        ; 'sm'
        STREQB  r0, [r2], #1

        LDR     r0, [r12, #Icon_Block + 24]
        LDRB    r1, [r0, #10]                   ; directoryo or small_diro?
        TEQ     r1, #'o'
        MOVEQ   r1, #'%'                        ; open, unselected
        MOVEQ   r3, #'&'                        ; open, selected
        MOVNE   r1, #'#'                        ; closed, unselected
        MOVNE   r3, #'$'                        ; closed, selected

        LDR     r0, [r12, #Icon_Block + 16]     ; flags
        TST     r0, #1<<21                      ; selected?
        BICNE   r0, r0, #1<<21                  ; yep - clear selected bit
        STRNE   r0, [r12, #Icon_Block + 16]
        MOVNE   r1, r3                          ; use selected sprite
        STRB    r1, [r2], #1

        LDR     r1, [r12, #Icon_Block + 20]     ; text address
        ; R2 setup
        ADD     r3, r12, #Scratch + 12          ; don't exceed remaining
        SUB     r3, r3, r2                      ; space
        BL      strncpy

        ADD     r2, r12, #Scratch

        B       checksprite

dynamic_app
        ; It's an application
        LDR     r0, [r12, #Flags]               ; user wants plings?
        TST     r0, #Flag_IgnorePlings
        BNE     wimp_ploticon_pre_ignore        ; they do - ignore

        LDR     r1, [r12, #Icon_Block + 20]     ; text string
        ADD     r1, r1, #1                      ; skip initial char (a pling)
        STR     r1, [r12, #Icon_Block + 20]

        LDR     r2, [r12, #Icon_Block + 24]     ; validation string
        ADD     r2, r2, #1                      ; skip initial char (an 'S')

        ; drops into ...

checksprite
        ; Checking sprite exists
        ; Expects: R2 -> sprite name
        MOV     r0, #&28
        SWI     XWimp_SpriteOp
        BVS     wimp_ploticon_pre_ignore        ; not known - ignore this one

        MOV     r1, r2                          ; update validation
        ADD     r2, r12, #NewValidation
        MOV     r3, #'S'
        STRB    r3, [r2], #1
        MOV     r3, #12
        BL      strncpy

        ADD     r2, r12, #NewValidation
        STR     r2, [r12, #Icon_Block + 24]

        B       wimp_ploticon_pre_exit


known
        ;
        ; Expects R8 setup
        ;

        ; Known thumbnail block
        ;

        ; Update bbox
        ;

        ADD     r0, r12, #Icon_Block
        LDMIA   r0, {r1-r4}
        ADD     r0, r8, #Icon_x0
        STMIA   r0, {r1-r4}

        ; Update 'half size'
        ;

        BL      is_it_small
        LDREQ   r0, [r12, #Icon_Block + 16]
        ORREQ   r0, r0, #1<<11
        STREQ   r0, [r12, #Icon_Block + 16]

        ; Update sprite validation string
        ;

        ADD     r0, r8, #Icon_Validation
        STR     r0, [r12, #Icon_Block + 24]
                                                ; fall-through
wimp_ploticon_pre_exit
        ;
        ; Change the next PlotIcon to use our block
        ;
        ADD     r14, r12, #Icon_Block
        STR     r14, [r13, #4]

        ; fall through

wimp_ploticon_pre_ignore
        ;
        ; Leave the next PlotIcon as it was
        ;
        Pull    "r0-r8, pc"

sprites_id
        DCB     "Sprites", 0
        ALIGN

is_it_small
        ; Exit:   EQ => Small
        ;         NE => Big

        Push    r14

        LDR     r0, [r12, #Icon_Block + 16]     ; flags
        MVN     r14, r0
        TST     r14, #1<<11                     ; 'half size' flag (not) set?
        BICEQ   r0, r0, #1<<11                  ; clear it, if so
        STREQ   r0, [r12, #Icon_Block + 16]
        BEQ     %FT99

        LDR     r0, [r12, #Icon_Block + 24]     ; validation address
        ; Assumes validation string starts "Sblah"
        LDRB    r14, [r0, #1]
        TEQ     r14, #'s'
        LDREQB  r14, [r0, #2]
        TEQEQ   r14, #'m'
        LDREQB  r14, [r0, #3]
        TEQEQ   r14, #'a'
        LDREQB  r14, [r0, #4]
        TEQEQ   r14, #'l'
        LDREQB  r14, [r0, #5]
        TEQEQ   r14, #'l'
        LDREQB  r14, [r0, #6]
        TEQEQ   r14, #'_'

99
        Pull    pc


; ---------------------------------------------------------------------------


wimp_ploticon_post
        ; Purpose: Called after Wimp_PlotIcon acts.

        LDR     r1, [r12, #PlotIcon]
        MOV     pc, r14

        END
