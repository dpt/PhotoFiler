; Filters for Wimp_Poll

	GET	Hdr.Debug
	GET	Hdr.Flags
	GET	Hdr.Options
	GET	Hdr.Symbols
	GET	Hdr.Workspace

	IMPORT  create_thumbnail
	IMPORT  sprcache_shrink
	IMPORT  heap_shrink

	EXPORT  wimp_prefilter
	EXPORT  wimp_postfilter
	EXPORT  shrink_need

	AREA	|filters_code|, CODE, READONLY


	; wimp_prefilter
	;
	; The Filer has called Wimp_Poll.
	;

wimp_prefilter
        STR	r14, [r13, #-4]!		; STMFD	r13!, {r14}

	; Enable null polls as required for the post filter

	LDR	r14, [r12, #Flags]

	TST	r14, #Flag_NeedUpdate		; if (NeedUpdate or
	TSTEQ	r14, #Flag_ShrinkHeaps		;     ShrinkHeaps or
	TSTEQ	r14, #Flag_RefreshAll		;     RefreshAll) then ...
	BICNE	r0, r0, #1			; clear null event mask bit
	BICNE	r0, r0, #1<<20			; clear the undoc mask bit 20

	TST	r14, #Flag_ShrinkHeaps
	BLNE	shrink

        LDR	pc, [r13], #4			; LDMFD	r13!, {pc}


	; shrink
	;
	; Called to reduce memory to smallest size.
	;

shrink
	STMFD	r13!, {r0, r14}

	SWI	XOS_ReadMonotonicTime
	LDR	r14, [r12, #ShrinkTime]
	CMP	r0, r14				; none needed if (unsigned)
	LDMCCFD	r13!, {r0, pc}			; less than.

	BL	sprcache_shrink
	BL	heap_shrink

	LDR	r0, [r12, #Flags]
	BIC	r0, r0, #Flag_ShrinkHeaps
	STR	r0, [r12, #Flags]

	LDMFD	r13!, {r0, pc}


	; shrink_need
	;
	; Called to indicate that the heaps need to shrink. It sets a
	; reminder and a time to shrink the heaps, so that it will only
	; perform a shrink when things are quiet.
	;

shrink_need
	STMFD	r13!, {r0, r14}

	SWI	XOS_ReadMonotonicTime		; shrink in one second
	ADD	r0, r0, #100
	STR	r0, [r12, #ShrinkTime]

	LDR	r0, [r12, #Flags]
	ORR	r0, r0, #Flag_ShrinkHeaps
	STR	r0, [r12, #Flags]

	LDMFD	r13!, {r0, pc}


	; wimp_postfilter
	;
	; Wimp_Poll has returned to the Filer.
	;
	; Called only when Flag_NeedUpdate
	;

wimp_postfilter
	STMFD	r13!, {r0-r8, r14}

	LDR	r14, [r12, #Flags]
	TST	r14, #Flag_RefreshAll
	BEQ	do_icons

	; force a redraw for all known displays

postfilter_refresh
	MOV	r1, #0
	SUB	r2, r1, #65536
	MOV	r3, #65536
	MOV	r4, #0
	LDR	r7, [r12, #Display_First]
refresh_window
	TEQ	r7, #0				; windows left?
	BEQ	refresh_exit
	LDR	r0, [r7, #Display_Handle]
	SWI	XWimp_ForceRedraw
	LDR	r7, [r7, #Display_Next]
	B	refresh_window
refresh_exit
	LDR	r0, [r12, #Flags]		; clear refresh flag
	BIC	r0, r0, #Flag_RefreshAll
	STR	r0, [r12, #Flags]

	; process all pending icons

do_icons
	SWI	XOS_ReadMonotonicTime
	LDR	r1, [r12, #TimeSlice]
	ADD	r5, r0, r1			; next time slot

	MOV	r6, #0				; done/'needs updating' flag
	LDR	r7, [r12, #Display_First]	; list of known directories
window
	TEQ	r7, #0				; windows left?
	BEQ	postfilter_exit
  [ HASHING <> 0
  	; ### for each icon block chain start
  ]
	LDR	r8, [r7, #Display_FirstIcon]
icon
	TEQ	r8, #0				; icons left?
	BEQ	done_window

	LDR	r0, [r8, #Icon_SpriteArea]
	TEQ	r0, #Icon_Make			; generate?
	BNE	done_icon			; no, next

	BL	create_thumbnail

	ADD	r0, r8, #Icon_x0		; update
	LDMIA	r0, {r1-r4}
	LDR	r0, [r7, #Display_Handle]
	SWI	XWimp_ForceRedraw
	BVS	exit

	MOV	r6, #1				; may need another update

	SWI	XOS_ReadMonotonicTime
	CMP	r0, r5				; exceeded time slot?
	BCS	postfilter_exit			; yes

done_icon
	LDR	r8, [r8, #Icon_Next]
	B	icon

done_window
	LDR	r7, [r7, #Display_Next]
	B	window

postfilter_exit					; all windows done
	LDR	r14, [r12, #Flags]		; update flag
	TEQ	r6, #1
	ORREQ	r14, r14, #Flag_NeedUpdate	; need updates
	BICNE	r14, r14, #Flag_NeedUpdate	; don't need updates
	STR	r14, [r12, #Flags]

exit
	LDMFD   r13!, {r0-r8, pc}		; exit with V clear


	END
