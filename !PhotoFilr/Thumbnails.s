; Creation and deletion of thumbnails

	GET	Hdr.Debug
	GET	Hdr.Flags
	GET	Hdr.Options
	GET	Hdr.Symbols
	GET	Hdr.Workspace

	IMPORT  divide
	IMPORT  heap_claim
	IMPORT  heap_release
	IMPORT  heap_resize
	IMPORT  shrink_need
	IMPORT  sprcache_resize
	IMPORT  strcpy
	IMPORT  wimp_palette_1bpp
	IMPORT  wimp_palette_1bpp_mode
	IMPORT  wimp_palette_2bpp
	IMPORT  wimp_palette_2bpp_mode
	IMPORT  wimp_palette_4bpp
	IMPORT  wimp_palette_4bpp_mode
	IMPORT  wimp_palette_8bpp
	IMPORT  wimp_palette_8bpp_mode

	EXPORT  create_thumbnail
	EXPORT  delete_thumbnail

	AREA	|thumbnail_code|, CODE, READONLY


create_thumbnail
	; Entry: R7 -> directory block
	;	 R8 -> icon block

	STMFD	r13!, {r0-r11, r14}

	DBF	"ENTER create_thumbnail\n"

	SWI	XHourglass_On

	;v3;LDR	r0, [r8, #Icon_Flags]
	;v3;TEQ	r0, #IconFlag_InProgress
	;v3;BNE	continue

	MOV	r0, #0				; no memory has yet been
	STR	r0, [r12, #Image_Address]	;  claimed

	LDR	r0, [r12, #Sprite_Counter]	; increment the generation
	ADD	r0, r0, #1			;  counter
	STR	r0, [r12, #Sprite_Counter]

	ADR	r0, vdu_variables_in		; update the vdu variables
	ADD	r1, r12, #Vdu_Variables
	SWI	XOS_ReadVduVariables
	BVS	create_thumbnail_error

	ADD	r0, r12, #Temp_Filename
	ADD	r1, r7, #Display_Path
make_filename
	LDRB	r2, [r1], #1
	CMP	r2, #' '
	STRCSB  r2, [r0], #1
	BCS	make_filename
	MOV	r2, #'.'
	STRB	r2, [r0], #1
	ADD	r1, r8, #Icon_Leafname
make_filename2
	LDRB	r2, [r1], #1
	CMP	r2, #' '
	STRCSB  r2, [r0], #1
	BCS	make_filename2
	LDR	r2, [r8, #Icon_Flags]		; append '.*'
	TST	r2, #IconFlag_ImageFS
	MOVNE	r2, #'.'
	STRNEB  r2, [r0], #1
	MOVNE	r2, #'*'
	STRNEB  r2, [r0], #1
	MOV	r2, #0
	STRB	r2, [r0], #1

	; Temp_Filename now holds whole filename

	MOV	r0, #17
	ADD	r1, r12, #Temp_Filename
	SWI	XOS_File
	BVS	create_thumbnail_error

	MOV	r2, r2, LSL #12
	MOV	r2, r2, LSR #20			; file type

	EOR	r14, r2, #&F00			; SpriteFile
	TEQ	r14, #&F9
	BEQ	create_thumbnail_sprite

	EOR	r14, r2, #&C00			; JPEG
	TEQ	r14, #&85
	BEQ	create_thumbnail_jpeg

	EOR	r14, r2, #&A00			; DrawFile
	TEQ	r14, #&FF
	BEQ	create_thumbnail_drawfile

  [ ARTWORKS <> 0
	EOR	r14, r2, #&D00			; ArtWorks
	TEQ	r14, #&94
	BEQ	create_thumbnail_artworks
  ]

	DBF	"UNKNOWN TYPE in create_thumbnail\n"

	; any unknown types will drop-through (shouldn't have any, mind)

create_thumbnail_error
	ADDVS	r0, r0, #4
	DBF	"Error: %0s\n", VS

	DBF	"FAILURE for create_thumbnail\n"

	LDR	r0, [r12, #Sprite_Counter]	; delete sprite now
	ADD	r1, r12, #Scratch		;  unused due to error
	MOV	r2, #12
	SWI	XOS_ConvertHex8
	MOV	r2, r0				; sprite name
	LDR	r1, [r12, #Sprites_Base]	; sprite area
	MOV	r0, #&19			; delete
	ORR	r0, r0, #&100
	SWI	XOS_SpriteOp			; (ignore any error)

	; Make validation string
	;

	ADD	r2, r8, #Icon_Validation
	MOV	r0, #'S'
	STRB	r0, [r2], #1
	ADR	r1, icon_error
	BL	strcpy

	MOV	r0, #Icon_Wimp			; sprite is in the Wimp pool

	B	create_thumbnail_exit

create_thumbnail_created
	DBF	"SUCCESS for create_thumbnail\n"

	LDR	r0, [r12, #Flags]		; mini icons
	TST	r0, #Flag_MiniIcons
	BEQ	nominis

  [	MINI_ICONS <> 0
	; Add file type icon to thumbnail
	;

	; Select sprite
	ADD	r2, r12, #Scratch
	LDR	r1, [r12, #Sprites_Base]
	MOV	r0, #&100
	ADD	r0, r0, #&018			; select thumbnail (24)
	SWI	XOS_SpriteOp			; returns R2 (offset)
	BVS	create_thumbnail_error

  [	OUTPUT_TO_SPRITE <> 0
	MOV	r0, #&3C			; switch output to sprite
	ORR	r0, r0, #&200
	; R1 -> sprite cache
	; R2 = offset
	MOV	r3, #0				; no save area
	SWI	XOS_SpriteOp
	BVS	create_thumbnail_error
  ]

	STMFD	r13!, {r0-r7}			; stash

	LDR	r0, small
	ADD	r1, r12, #SmallSpriteName
	LDR	r2, small + 4
	STMIA	r1, {r0, r2}			; 'small\0'

	LDR	r0, [r8, #Icon_FileType]
	ADD	r1, r1, #5			; 'smallXXXX\0'
	MOV	r2, #5
	SWI	OS_ConvertHex4

	MOV	r1, #'_'
	STRB	r1, [r0]			; 'small_XXX\0'

	; Can't really use Wimp_BaseOfSprites (it's deprecated)
	; Can't really use Wimp_ReadPixTrans for colours (it doesn't work)
	; Can't really use Wimp_PlotIcon (it fails to work when redirected)

	MOV	r0, #&28			; read sprite info
	ADD	r2, r12, #SmallSpriteName
	SWI	XWimp_SpriteOp
	BVS	mini_end
	; R3, R4, R5, R6 = width, height, mask, mode

	; Construct scale block for sprite plot
	MOV	r0, r6				; spr_mode
	MOV	r1, #4				; get spr_xeig
	SWI	XOS_ReadModeVariable
	MOV	r3, #1
	MOV	r3, r3, LSL r2			; mul x = 1 << spr_xeig
	MOV	r1, #5				; get spr_yeig
	SWI	XOS_ReadModeVariable
	MOV	r4, #1
	MOV	r4, r4, LSL r2			; mul y = 1 << spr_yeig
	MOV	r0, #-1				; cur_mode
	MOV	r1, #4				; get cur_xeig
	SWI	XOS_ReadModeVariable
	MOV	r5, #1
	MOV	r5, r5, LSL r2			; div x = 1 << cur_xeig
	MOV	r1, #5				; get cur_yeig
	SWI	XOS_ReadModeVariable
	MOV	r7, #1
	MOV	r7, r7, LSL r2			; div y = 1 << cur_yeig
	; R3, R4, R5, R7 = mul x, mul y, div x, div y
	ADD	r6, r12, #Scale_Block
	STMIA	r6, {r3, r4, r5, r7}

	MOV	r0, #&25			; create/remove palette
	ADD	r2, r12, #SmallSpriteName
	MOV	r3, #-1				; read current palette size
	SWI	XWimp_SpriteOp
	BVS	mini_end
	; R3, R4, R5 = palette size, pointer to palette, mode

	MOV	r0, r5				; source mode

	TEQ	r3, #0
	MOVNE	r1, r4				; pointer to palette
	BNE	mini_gentab

;mini_unpaletted
	; R0 = source mode
	MOV	r1, #9				; get log2bpp
	SWI	XOS_ReadModeVariable
	; R2 = log2bpp
	CMP	r2, #4				; 32K, 16M and higher
	; MOVHS r0, r0				; source mode
	MOVHS	r1, #-1				; current palette
	TEQ	r2, #3
	LDREQ	r0, wimp_palette_8bpp_mode
	ADREQL  r1, wimp_palette_8bpp
	TEQ	r2, #2
	LDREQ	r0, wimp_palette_4bpp_mode
	ADREQL  r1, wimp_palette_4bpp
	TEQ	r2, #1
	LDREQ	r0, wimp_palette_2bpp_mode
	ADREQL  r1, wimp_palette_2bpp
	TEQ	r2, #0
	LDREQ	r0, wimp_palette_1bpp_mode
	ADREQL  r1, wimp_palette_1bpp

mini_gentab
	; R0 = source mode
	; R1 -> source palette
	MOV	r2, #-1				; current mode
	MOV	r3, #-1				; current palette
	ADD	r4, r12, #TranslationTable
	MOV	r5, #0				; flags
	SWI	XColourTrans_GenerateTable
	BVS	mini_end
	; R6 (-> scale block) hopefully intact
	MOV	r7, r4				; translation table

;mini_plot
	; R6 -> scale block
	; R7 -> translation table
	MOV	r0, #52				; Put sprite scaled
	ADD	r2, r12, #SmallSpriteName
	MOV	r3, #0
	MOV	r4, #0
	MOV	r5, #2_1000			; plot action (use mask)
	; R6 -> scale block
	; R7 -> translation table
	SWI	XWimp_SpriteOp
	; ignore errors
mini_end
	LDMFD	r13!, {r0-r7}			; grab

  [	OUTPUT_TO_SPRITE <> 0
	SWI	XOS_SpriteOp			; restore
	BVS	create_thumbnail_error
  ]

nominis
  ]

	; Make validation string
	;

	ADD	r2, r8, #Icon_Validation
	MOV	r0, #'S'
	STRB	r0, [r2], #1
	ADD	r1, r12, #Scratch
	BL	strcpy

	MOV	r0, #Icon_Ours			; sprite is in our own pool

create_thumbnail_exit
	STR	r0, [r8, #Icon_SpriteArea]

	LDR	r0, [r12, #Image_Address]	; deallocate any memory
	TEQ	r0, #0
	BLNE	heap_release

	SWI	XHourglass_Off

	DBF	"EXIT create_thumbnail\n"

	MRS	r14, CPSR
	ORR	r14, r14, #1<<28		; set V
	MSR	CPSR_f, r14
	LDMFD	r13!, {r0-r11, pc}


icon_error
	DCB	"file_error", 0
	ALIGN

small
	DCB	"small", 0
	ALIGN

vdu_variables_in
	DCD	4, 5, 9, -1


create_thumbnail_sprite
	; Entry: regs as exit from OS_File
	CMP	r4, #60				; spritefiles are at least
	BLT	create_thumbnail_error		;  60 bytes long

	ADD	r4, r4, #4			; sprite area size
	MOV	r0, r4				; bytes to claim
	BL	heap_claim
	BVS	create_thumbnail_error

	STR	r0, [r12, #Image_Address]
	MOV	r11, r0				; keep file address

	STR	r4, [r0]			; set sprite area size

	; Load sprite file
	MOV	r2, r1
	MOV	r1, r0				; sprite area
	MOV	r0, #&100
	ADD	r0, r0, #10			; load sprite file (10)
	SWI	XOS_SpriteOp
	BVS	create_thumbnail_error

	MOV	r1, r11
	MOV	r0, #&100
	ADD	r0, r0, #17			; verify sprite area (17)
	SWI	XOS_SpriteOp
	BVS	create_thumbnail_error

	; Check for palette
	LDR	r0, [r11, #8]			; offset to header
	ADD	r0, r0, r11			; -> sprite header
	LDR	r1, [r0, #32]			; offset to sprite data
	TEQ	r1, #44				; palette present?
	BEQ	sprite_no_palette		; no
sprite_has_palette
	; Building translation table (has palette)
	MOV	r0, r11				; sprite area
	LDR	r1, [r11, #8]			; offset to header
	ADD	r1, r1, r11			; -> sprite header
	B	sprite_do_trans
sprite_no_palette
	; Build translation table (no palette)
	LDR	r0, [r0, #40]			; mode
	MOV	r1, #9				; get log2bpp
	SWI	XOS_ReadModeVariable
	BVS	create_thumbnail_error
	CMP	r2, #4
	BHS	sprite_has_palette
	TEQ	r2, #3
	LDREQ	r0, wimp_palette_8bpp_mode
	ADREQL  r1, wimp_palette_8bpp
	TEQ	r2, #2
	LDREQ	r0, wimp_palette_4bpp_mode
	ADREQL  r1, wimp_palette_4bpp
	TEQ	r2, #1
	LDREQ	r0, wimp_palette_2bpp_mode
	ADREQL  r1, wimp_palette_2bpp
	TEQ	r2, #0
	LDREQ	r0, wimp_palette_1bpp_mode
	ADREQL  r1, wimp_palette_1bpp
sprite_do_trans
	MOV	r2, #-1				; current mode
	MOV	r3, #-1				; current palette
	ADD	r4, r12, #TranslationTable
	MOV	r5, #2_1			; pointer to sprite
	SWI	XColourTrans_GenerateTable
	BVS	create_thumbnail_error

	; Read sprite info
	MOV	r0, #&28			; read sprite info
	ORR	r0, r0, #&200
	MOV	r1, r11				; sprite area
	LDR	r2, [r11, #8]			; offset to header
	ADD	r2, r2, r11			; -> sprite header
	SWI	XOS_SpriteOp			; R3 = width, R4 = height
	BVS	create_thumbnail_error

	; Scale
	MOV	r0, r6				; mode
	MOV	r1, #4				; source_xeig
	SWI	XOS_ReadModeVariable
	MOV	r3, r3, LSL r2			; os_w = w << source_xeig
	MOV	r5, r2
	MOV	r1, #5				; source_yeig
	SWI	XOS_ReadModeVariable
	MOV	r4, r4, LSL r2			; os_h = h << source_yeig
	MOV	r6, r2
	; R3, R4 holds width, height in OS units
	BL	sprite
	BVS	create_thumbnail_error
	; R0 holds scale factor
	ADD	r0, r0, #1			; fudge the scale factor :-(
	MOV	r1, r0, LSL r5			; x-mul
	MOV	r2, r0, LSL r6			; y-mul
	MOV	r0, #&10000
	LDR	r3, [r12, #XEigFactor]
	MOV	r3, r0, LSL r3			; x-div
	LDR	r4, [r12, #YEigFactor]
	MOV	r4, r0, LSL r4			; y-div
	ADD	r0, r12, #Scale_Block
	STMIA	r0, {r1-r4}

	; Paint sprite
	MOV	r0, #&18			; select sprite thumbnail
	ORR	r0, r0, #&100
	LDR	r1, [r12, #Sprites_Base]
	ADD	r2, r12, #Scratch
	SWI	XOS_SpriteOp			; returns R2 (offset)
	BVS	create_thumbnail_error

  [	OUTPUT_TO_SPRITE <> 0
	MOV	r0, #&3C			; switch output to sprite
	ORR	r0, r0, #&200
	; R1 -> sprite cache
	; R2 = offset
	MOV	r3, #0				; no save area
	SWI	XOS_SpriteOp
	BVS	create_thumbnail_error
  ]

	STMFD	r13!, {r0-r7}
	; Clear background to white
	MOV	r0, #&FFFFFF00			; white
	MOV	r3, #3<<7			; bg, use ecfs.
	MOV	r4, #0
	SWI	XColourTrans_SetGCOL
	SWI	XOS_WriteI + 16			; CLS

	; Plot sprite
	MOV	r0, #&34			; put sprite scaled
	ORR	r0, r0, #&200
	MOV	r1, r11				; sprite area
	LDR	r2, [r1, #8]
	ADD	r2, r1, r2			; sprite
	MOV	r3, #0
	MOV	r4, #0

	MOV	r5, #2_1000			; plot action (b3) use mask
	LDR	r14, [r12, #Flags]		; dithering
	AND	r14, r14, #Flag_SpriteDithering
	ORR	r5, r5, r14, LSL #5		; (b6) dithering [assumption]

	ADD	r6, r12, #Scale_Block
	ADD	r7, r12, #TranslationTable
	SWI	XOS_SpriteOp
	LDMFD	r13!, {r0-r7}

	; Switch output back from sprite
  [	OUTPUT_TO_SPRITE <> 0
	SWI	XOS_SpriteOp			; restore
	BVS	create_thumbnail_error
  ]

	B	create_thumbnail_created

create_thumbnail_jpeg
	; Entry: regs as exit from OS_File

	CMP	r4, #160			; JPEG images are at least
	BLT	create_thumbnail_error		;  160 bytes long

	MOV	r9, r4				; keep file length

	; Claim heap memory
	MOV	r0, r9
	BL	heap_claim
	BVS	create_thumbnail_error		; claim failed

	STR	r0, [r12, #Image_Address]
	MOV	r11, r0				; keep file address

	; Load JPEG
	MOV	r3, #0
	MOV	r2, r11				; address
	ADD	r1, r12, #Temp_Filename
	MOV	r0, #16
	SWI	XOS_File
	BVS	create_thumbnail_error

	; Validate JPEG
	ADD	r1, r11, r4			; last byte + 1
	SUB	r1, r1, #2
validate_jpeg_loop
	LDRB	r0, [r1], #-1
	TEQ	r0, #&FF
	LDREQB  r0, [r1, #2]			; we've found an &FF, does
	TEQEQ	r0, #&D9			;  &D9 follow it?
	BEQ	validate_jpeg_ok
	CMP	r1, r11				; have we hit start of JPEG?
	BHS	validate_jpeg_loop
	B	create_thumbnail_error

validate_jpeg_ok
	; Read JPEG dimensions
	MOV	r2, r9
	MOV	r1, r11				; address
	MOV	r0, #1				; return dimensions
	SWI	XJPEG_Info			; R2 = width, R3 = height
	BVS	create_thumbnail_error

	; Scale and create thumbnail
	MOV	r4, r3, LSL #1
	MOV	r3, r2, LSL #1
	; R3, R4 holds width, height in OS units
	BL	sprite
	BVS	create_thumbnail_error
	; R0 holds scale factor
	ADD	r0, r0, #1			; fudge the scale factor :-(
	MOV	r1, r0, LSL #1			; x-mul
	MOV	r2, r0, LSL #1			; y-mul
	MOV	r0, #&10000
	LDR	r3, [r12, #XEigFactor]
	MOV	r3, r0, LSL r3			; x-div
	LDR	r4, [r12, #YEigFactor]
	MOV	r4, r0, LSL r4			; y-div
	ADD	r0, r12, #Scale_Block
	STMIA	r0, {r1-r4}

;
; The code in make_sprite to force thumbnails to a minimum of 4x4 OS units
; SHOULD make this code redundant.
;
;	; Check thumbnail isn't one pixel wide
;	; or high (to avoid JPEG bug)
;	ADD	r2, r12, #Scratch
;	LDR	r1, [r12, #Sprites_Base]
;	MovL	r0, &128			; read sprite info (40)
;	Stash	"r3-r6"
;	SWI	XOS_SpriteOp
;	TEQ	r3, #1
;	TEQNE	r4, #1
;	Grab	"r3-r6"
;	BEQ	create_thumbnail_error

	; Select sprite
	ADD	r2, r12, #Scratch
	LDR	r1, [r12, #Sprites_Base]
	MOV	r0, #&100
	ADD	r0, r0, #24			; select thumbnail (24)
	SWI	XOS_SpriteOp			; returns R2 (offset)
	BVS	create_thumbnail_error

  [	OUTPUT_TO_SPRITE <> 0
	; Switch output to sprite
	MOV	r3, #0				; no save area
	; R2 = offset
	; R1 -> sprite cache
	MOV	r0, #&200
	ADD	r0, r0, #60			; switch output to sprite
	SWI	XOS_SpriteOp
	BVS	create_thumbnail_error
  ]

	STMFD	r13!, {r0-r4}
	; Clear background to white
	MOV	r0, #&FFFFFF00			; white
	MOV	r3, #3<<7			; bg, use ecfs.
	MOV	r4, #0
	SWI	XColourTrans_SetGCOL
	SWI	XOS_WriteI + 16			; CLS

	MOV	r0, r11				; address
	MOV	r1, #0
	MOV	r2, #0
	ADD	r3, r12, #Scale_Block
	MOV	r4, r9
	LDR	r5, [r12, #Flags]		; dithering
	AND	r5, r5, #Flag_JPEGDithering
	MOV	r5, r5, LSR #9			; [assumption]
	SWI	XJPEG_PlotScaled
	LDMFD	r13!, {r0-r4}

	; Switch output back from sprite
  [	OUTPUT_TO_SPRITE <> 0
	SWI	XOS_SpriteOp			; restore
	BVS	create_thumbnail_error
  ]

	B	create_thumbnail_created


create_thumbnail_drawfile
	; Entry: regs as exit from OS_File

	CMP	r4, #40				; DrawFiles are at least
	BLT	create_thumbnail_error		;  40 bytes long

	MOV	r9, r4				; keep file length

	; Claim heap memory
	MOV	r0, r9
	BL	heap_claim
	BVS	create_thumbnail_error		; claim failed

	STR	r0, [r12, #Image_Address]
	MOV	r11, r0				; keep file address

	; Load DrawFile
	MOV	r0, #16
	ADD	r1, r12, #Temp_Filename
	MOV	r2, r11				; address
	MOV	r3, #0
	SWI	XOS_File
	BVS	create_thumbnail_error

	MOV	r0, #0
	MOV	r1, r11				; address
	MOV	r2, r4				; length
	MOV	r3, #0
	ADD	r4, r12, #Draw_BBox
	SWI	XDrawFile_BBox
	BVS	create_thumbnail_error

	MOV	r0, r4
	LDMIA	r0, {r1-r4}
	SUB	r3, r3, r1			; catch empty/-ve bboxes
	CMP	r3, #0				; if (w < 0)
	SUBGT	r4, r4, r2			;
	CMPGT	r4, #0				;  or (h < 0) then
	BLE	create_thumbnail_error		;  fail

	MOV	r3, r3, LSR #8			; width in OS units
	MOV	r4, r4, LSR #8			; height in OS units
	BL	sprite
	BVS	create_thumbnail_error

	STR	r0, [r12, #Draw_Transform + 0] ; store scale
	STR	r0, [r12, #Draw_Transform + 12]
	MOV	r2, r2, ASR #8			; -(scale*(bbox!4>>8))>>8
	MUL	r2, r0, r2
	MOV	r2, r2, ASR #8
	RSB	r2, r2, #0
	STR	r2, [r12, #Draw_Transform + 20]
	MOV	r1, r1, ASR #8			; -(scale*(!bbox>>8))>>8
	MUL	r1, r0, r1
	MOV	r1, r1, ASR #8
	RSB	r1, r1, #0
	STR	r1, [r12, #Draw_Transform + 16]
	MOV	r0, #0
	STR	r0, [r12, #Draw_Transform + 4]
	STR	r0, [r12, #Draw_Transform + 8]

	MOV	r0, #&18			; select sprite thumbnail
	ORR	r0, r0, #&100
	LDR	r1, [r12, #Sprites_Base]
	ADD	r2, r12, #Scratch
	SWI	XOS_SpriteOp			; returns R2 (offset)
	BVS	create_thumbnail_error

  [	OUTPUT_TO_SPRITE <> 0
	; Switch output to sprite
	MOV	r0, #&3C			; switch output to sprite
	ORR	r0, r0, #&200
	; R1 -> sprite cache
	; R2 = offset
	MOV	r3, #0				; no save area
	SWI	XOS_SpriteOp
	BVS	create_thumbnail_error
  ]

	STMFD	r13!, {r0-r4}
	; Clear background to white
	MOV	r0, #&FFFFFF00			; white
	MOV	r3, #3<<7			; bg, use ecfs.
	MOV	r4, #0
	SWI	XColourTrans_SetGCOL
	SWI	XOS_WriteI + 16			; CLS

	MOV	r0, #0
	MOV	r1, r11				; address
	MOV	r2, r9				; length
	ADD	r3, r12, #Draw_Transform
	MOV	r4, #0
	SWI	XDrawFile_Render
	LDMFD	r13!, {r0-r4}

	; Switch output back from sprite
  [	OUTPUT_TO_SPRITE <> 0
	SWI	XOS_SpriteOp			; restore
	BVS	create_thumbnail_error
  ]

	B	create_thumbnail_created


  [ ARTWORKS <> 0
create_thumbnail_artworks
	; Entry: regs as exit from OS_File

	DBF	"ENTER create_thumbnail_artworks\n"

	CMP	r4, #2048			; approximate minimum size
	BLT	create_thumbnail_error

	MOV	r9, r4				; keep file length

	DBF	"Claim a heap memory block for the file\n"

	MOV	r0, r9
	BL	heap_claim
	BVS	create_thumbnail_error

	STR	r0, [r12, #Image_Address]
	MOV	r11, r0				; keep file address

	DBF	"Load the file into claimed heap block\n"

	MOV	r0, #16
	ADD	r1, r12, #Temp_Filename
	MOV	r2, r11				; address
	MOV	r3, #0
	SWI	XOS_File
	BVS	create_thumbnail_error

	DBF	"Set up memory for init\n"

	MOV	r0, r11				; resizable block
	MOV	r1, r9				; resizable size
	MOV	r2, #-1				; fixed block
	MOV	r3, r9				; fixed size
	ADD	r4, r12, #AWRender_Memory
	STMIA	r4, {r0-r3}

	DBF	"after init: resizable at %0w, %1w long\n"
	DBF	"after init: fixed     at %2w, %3w long\n"

	DBF	"Initialise the file (convert it, if necessary)\n"

	SWI	XAWRender_FileInitAddress
	BVS	create_thumbnail_error
	; R0 = address of file init routine
	; R1 = file init routine's R12

	STR	r12, stashed_r12		; used by callback

	MOV	r10, r0				; FileInit routine
	MOV	r12, r1				; FileInit routine's R12

	MOV	r0, r11				; document address
	ADR	r1, awrender_callback
	MOV	r2, r9				; document length
	MOV	r14, pc
	MOV	pc, r10

	LDR	r12, stashed_r12		; even if VS

	BVS	create_thumbnail_error

	DBF	"Determine the document's bounding box\n"

	MOV	r0, r11
	SWI	XAWRender_DocBounds
	; Martin says DocBounds never returns with VS
	;BVS	create_thumbnail_error
	; R2-R5 = bounding box (x0, y0, x1, y1)
	DBF	"bbox is %2w %3w %4w %5w\n"
	MOV	r1, r2
	MOV	r2, r3
	MOV	r3, r4
	MOV	r4, r5
	SUB	r3, r3, r1			; catch empty/-ve bboxes
	CMP	r3, #0				; if (w <= 0)
	SUBGT	r4, r4, r2			;
	CMPGT	r4, #0				;  or (h <= 0) then
	BLE	create_thumbnail_error		;  fail
	DBF	"width x height is %3w x %4w\n"

	DBF	"Make an appropriately sized sprite\n"

	MOV	r3, r3, LSR #8			; width in OS units
	MOV	r4, r4, LSR #8			; height in OS units
	BL	sprite
	BVS	create_thumbnail_error
	; R0 = scale factor

	; R1 = bbox x0, R2 = bbox y0

	DBF	"Set up render transform block\n"

	STR	r0, [r12, #Draw_Transform + 0] 	; store scale
	STR	r0, [r12, #Draw_Transform + 12]
	MOV	r2, r2, ASR #8			; -(scale*(bbox!4>>8))>>8
	MUL	r2, r0, r2
	MOV	r2, r2, ASR #8
	RSB	r2, r2, #0
	STR	r2, [r12, #Draw_Transform + 20]
	MOV	r1, r1, ASR #8			; -(scale*(!bbox>>8))>>8
	MUL	r1, r0, r1
	MOV	r1, r1, ASR #8
	RSB	r1, r1, #0
	STR	r1, [r12, #Draw_Transform + 16]
	MOV	r0, #0
	STR	r0, [r12, #Draw_Transform + 4]
	STR	r0, [r12, #Draw_Transform + 8]

	DBF	"Set up render information block\n"

	MOV	r0, #0
	STR	r0, [r12, #XDitherOrigin]
	STR	r0, [r12, #YDitherOrigin]
	;STR	r0, [r12, #XPrinterRect]	; n/a
	;STR	r0, [r12, #YPrinterRect]	; n/a
	;STR	r0, [r12, #PDriverJob]		; n/a
	STR	r0, [r12, #ClipRect_x0]
	STR	r0, [r12, #ClipRect_y0]
	MOV	r0, #&80000000
	SUB	r0, r0, #1			; = &7FFFFFFF
	STR	r0, [r12, #ClipRect_x1]
	STR	r0, [r12, #ClipRect_y1]

	DBF	"Add palette to VDU variables\n"

	ADD	r1, r12, #WimpPalette
	LDR	r2, =&45555254			; "TRUE"
	SWI	XWimp_ReadPalette
	; R0 corrupt
	BVS	create_thumbnail_error

	DBF	"Set up memory for render\n"

	MOV	r0, #512			; awrender workspace
	BL	heap_claim
	BVS	create_thumbnail_error

	; R0 = resizable block
	MOV	r1, #512			; resizable size
	MOV	r2, r11				; fixed block
	MOV	r3, r9				; fixed size
	ADD	r4, r12, #AWRender_Memory
	STMIA	r4, {r0-r3}

	MOV	r0, #&18			; select sprite thumbnail
	ORR	r0, r0, #&100
	LDR	r1, [r12, #Sprites_Base]
	ADD	r2, r12, #Scratch
	SWI	XOS_SpriteOp			; returns R2 (offset)
	BVS	create_thumbnail_error

  [  OUTPUT_TO_SPRITE <> 0
	DBF	"Switch output to sprite\n"

	MOV	r0, #&3C			; switch output to sprite
	ORR	r0, r0, #&200
	; R1 -> sprite cache
	; R2 = offset
	MOV	r3, #0				; no save area
	SWI	XOS_SpriteOp
	BVS	create_thumbnail_error
  ]

	STMFD	r13!, {r0-r4, r12}

	; Clear background to white
	MOV	r0, #&FFFFFF00			; white
	MOV	r3, #3<<7			; bg, use ecfs.
	MOV	r4, #0
	SWI	XColourTrans_SetGCOL
	SWI	XOS_WriteI + 16			; CLS

	DBF	"Render to the sprite\n"

	SWI	XAWRender_RenderAddress
	BVS	%FT00
	; R0 = address of file init routine
	; R1 = file init routine's R12

	MOV	r14, r12			; temp wksp

	MOV	r10, r0				; routine
	MOV	r12, r1				; routine's R12

	MOV	r0, r11				; document
	ADD	r1, r14, #AWRender_Information
	ADD	r2, r14, #Draw_Transform
	ADD	r3, r14, #Vdu_Variables
	LDR	r4, [r14, #AWRender_Memory + 0] ; resizable block
	ADR	r5, awrender_callback
	LDR	r6, [r14, #ArtWorks_Quality]	; WYSIWYG setting
	MOV	r7, #0				; OutputToVDU

	MOV	r14, pc
	MOV	pc, r10

00
	LDMFD	r13!, {r0-r4, r12}

  [  OUTPUT_TO_SPRITE <> 0
	DBF	"Switch output back\n"

	SWI	XOS_SpriteOp			; restore
	BVS	create_thumbnail_error
  ]

	DBF	"Release render memory\n"

	LDR	r0, [r12, #ResizableBase]
	BL	heap_release

	B	create_thumbnail_created

stashed_r12
	DCD	0				; for my stashed R12

awrender_callback
	DBF	"ENTER awrender_callback, R11=%Bw\n"

	TEQ	r11, #0				; CallBackReason_Memory
	BNE	%FT99

	DBF	"memory, R0=%0w\n"

	; R0 = new size of resizable block, or -1 to read size of block

	CMP	r0, #-1
	BEQ	returnsizes

	STMFD	r13!, {r4, r12, r14}

	DBF	"memory claim, R0=%0w\n"

	LDR	r12, stashed_r12		; get my R12

	MOV	r4, r0				; keep desired size

	LDR	r0, [r12, #ResizableBase]
	LDR	r1, [r12, #ResizableSize]
	SUB	r1, r4, r1			; delta
	BL	heap_resize
	; R0 = new base
	BVS	awrender_callback_exit

	STR	r0, [r12, #ResizableBase]
	MOV	r1, r4
	STR	r1, [r12, #ResizableSize]
	LDR	r2, [r12, #FixedBase]
	LDR	r3, [r12, #FixedSize]

	DBF	"resizable:%0w+%1w fixed:%2w+%3w\n"

	; R0 = base of resizable block
	; R1 = size of resizable block
	; R2 = base of fixed block (or -1 if none)
	; R3 = size of fixed block (or document in resizable block)

awrender_callback_exit
	DBF	"EXIT awrender_callback\n"

	LDMFD	r13!, {r4, r12, pc}

returnsizes
	LDR	r1, stashed_r12			; get my R12
	ADD	r0, r1, #AWRender_Memory
	LDMIA	r0, {r0-r3}
	DBF	"request: resizable at %0w, %1w long\n"
	DBF	"request: fixed     at %2w, %3w long\n"

99
	CMN	pc, #0				; Sets nzcv
	DBF	"returning\n"
	MOV	pc, r14
  ]


; ### sprite, jpeg and drawfile thumbnails all suffer from problem if an
;     error is caused by the actual rendering swi.  output must be switched
;     back from sprite and then the _error routine branched to /if/ the error
;     occurred.


sprite
	; Entry: R3 = source image width in OS units
	;	 R4 = source image height in OS units
	; Exit:  R0 = scale factor

	STMFD	r13!, {r1-r10, r14}

	; Sanity-check size
	LDR	r9, [r12, #Thumb_MaxWidth]
	TEQ	r9, #0
	LDRNE	r10, [r12, #Thumb_MaxHeight]
	TEQNE	r10, #0
	MSREQ	cpsr_f, #1<<28			; set nzcV
	LDMEQFD	r13!, {r1-r10, pc}

	CMP	r3, r9				; if (w < maxw) and
	CMPLT	r4, r10				;    (h < maxh) then
	MOVLT	r5, r3				;   neww = w
	MOVLT	r6, r4				;   newh = h, else
	MOVGE	r5, r9				;   neww = maxw
	MOVGE	r6, r10				;   newh = maxh

	; Calculate scaling factor
	MOV	r0, r6, LSL #16
	MOV	r1, r4				; (thumb_height<<16)/os_height
	BL	divide				; R0 = scale
	LDMVSFD r13!, {r1-r10, pc}
	MUL	r9, r3, r0
	MOV	r9, r9, LSR #16			; R9 = new_thumb_width
	MOV	r10, r6				; R10 = new_thumb_height
	CMP	r9, r5				; width <= widest?
	BLE	sprite_make			; no

	; 'Wide' sprite: recalculate scaling factor
	MOV	r0, r5, LSL #16
	MOV	r1, r3				; (thumb_width<<16)/os_width
	BL	divide				; R0 = scale
	LDMVSFD r13!, {r1-r10, pc}
	MOV	r9, r5				; R9 = new_thumb_width
	MUL	r10, r0, r4
	MOV	r10, r10, LSR #16		; R10 = new_thumb_height

sprite_make
	; Make sprite
	MOV	r1, r9
	MOV	r2, r10
	BL	make_sprite

	LDMFD	r13!, {r1-r10, pc}


make_sprite
	; Entry: R1 = width  (OS units)
	;	 R2 = height (OS units)
	;	 R7 -> directory block
	;	 R8 -> icon block

	STMFD	r13!, {r0-r6, r14}

	CMP	r1, #4
	MOVLT	r1, #4
	CMP	r2, #4
	MOVLT	r2, #4

	; Convert to pixel dimensions for the current mode
	LDR	r0, [r12, #XEigFactor]
	MOV	r4, r1, LSR r0
	LDR	r0, [r12, #YEigFactor]
	MOV	r5, r2, LSR r0

	; Allocate space
	;  (((((w<<log2bpp)+31)AND(NOT(31)))>>3)*h)+44  Easy! :-)
	LDR	r1, [r12, #Log2BPP]
	MOV	r1, r4, LSL r1
	ADD	r1, r1, #31
	BIC	r1, r1, #31
	MOV	r1, r1, LSR #3
	MUL	r1, r5, r1			; =size of data
	ADD	r1, r1, #44			; add header size

	LDR	r2, [r12, #Sprites_Base]
	LDR	r0, [r2, #0]			; total area size
	LDR	r2, [r2, #12]			; offset to first free word
	SUB	r0, r0, r2			; free in area

	CMP	r0, r1
  [ FREE_WORD_WORKAROUND <> 0
	; Note the behaviour here carefully.  The BGT ensures that there is
	; always a free word at the end of the sprite area, since switched
	; output was causing crashes in UtilityModule caused by it trying to
	; access the word after the end of the dynamic area.
	BGT	dont_claim			; (was BGE)
  |
	BGE	dont_claim
  ]

	BL	sprcache_resize			; R1 = amount of space needed
	LDMVSFD r13!, {r0-r6, pc}		; return with flags

dont_claim
	LDR	r0, [r12, #Sprite_Counter]
	ADD	r1, r12, #Scratch
	MOV	r2, #12
	SWI	XOS_ConvertHex8
	LDMVSFD r13!, {r0-r6, pc}		; return with flags

	; Create the sprite
	MOV	r0, #-1				; current mode
	MOV	r6, #1				; mode specifier

	MOV	r1, #180
	LDR	r2, [r12, #XEigFactor]
	MOV	r2, r1, LSR r2			; dpi
	ORR	r6, r6, r2, LSL #1

	;MOV	r1, #180
	LDR	r2, [r12, #YEigFactor]
	MOV	r2, r1, LSR r2			; dpi
	ORR	r6, r6, r2, LSL #14

	LDR	r2, [r12, #Log2BPP]
	ADD	r2, r2, #1
	ORR	r6, r6, r2, LSL #27

	MOV	r3, #0				; palette flag
	ADD	r2, r12, #Scratch		; sprite name
make_sprite_create
	LDR	r1, [r12, #Sprites_Base]
	MOV	r0, #&0F			; create
	ORR	r0, r0, #&100
	SWI	XOS_SpriteOp
	LDMFD	r13!, {r0-r6, pc}


delete_thumbnail
	; Entry: R8 -> icon block

	STMFD	r13!, {r0-r2, r14}

	LDR	r0, [r8, #Icon_SpriteArea]
	TEQ	r0, #Icon_Ours
	LDMNEFD r13!, {r0-r2, pc}		; not our sprite

	BL	shrink_need

	MOV	r0, #&19
	ORR	r0, r0, #&100
	LDR	r1, [r12, #Sprites_Base]
	ADD	r2, r8, #Icon_Validation
	ADD	r2, r2, #1			; skip initial 'S'
	SWI	XOS_SpriteOp			; delete it from sprite area

	LDMFD	r13!, {r0-r2, pc}


	END
