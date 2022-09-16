# Bitmap Project

# Instructions:
#	1) Set pixel dimensions to 8x8
#	2) Set display demensions to 512x512 (Also resize the window)
#	3) Set base address to 0x10010000 (static data)
#	4) Connect bitmap display
#	5) Connect keyboard
#	6) Run

# Controls:
# w 	(up)
# a 	(left)
# s 	(down)
# d 	(right)
# r	(reset canvas)
# f	(start/stop the game)
# e	(exit)
# space	(place/remove pixels)
# 0-9	load templates

.eqv	WINDOW_WIDTH	64		# Window Width (512 / 8) = 64
.eqv	WINDOW_HEIGHT	64		# Window Height (512 / 8) = 64
.eqv	WIDTH		64		# Canvas Width (512 / 8) = 64
.eqv	HEIGHT		64		# Canvas Height (512 / 8) = 64

.eqv	CURSOR_X	32		# Middle of display
.eqv	CURSOR_Y	32		# Middle of display

.eqv	ARR_SIZE	4096		# Size of cell arrays (64 * 64)
.eqv	ARR_SIZE_BYTES	16384		# Size of cell arrays (64 * 64) * 4

.eqv	TEMPLATE_ID	$s1

.eqv	PREV_ARR	$s2		# Base memory Address of (0, 0) for the cell previous state array
.eqv	EDITING_ARR	$s3		# Base memory Address of (0, 0) for the cell editing array
.eqv	READ_ARR	$s4		# Base memory Address of (0, 0) for the cell read array
.eqv	CHANGE_ARR	$s5		# Base memory Address of (0, 0) for the cell change array

.eqv	CAMERA_X	$s6		# X value of the camera off set
.eqv	CAMERA_Y	$s7		# Y value of the camera off set

.eqv	MEM		0x10010000	# Base memory Address of (0, 0) for the display

# Colors
.eqv	BLACK		0x00000000
.eqv	WHITE		0x00FFFFFF
.eqv	BLUE		0x0088FFFF
	
	.data

display_mem:	.space	ARR_SIZE_BYTES	# (64 * 64) * 4 = 16384
editing_arr:	.space	ARR_SIZE_BYTES  # Memory Address of (0, 0) for the editing array
read_arr:	.space	ARR_SIZE_BYTES	# Memory Address of (0, 0) for the cell read array
change_arr:	.space	ARR_SIZE_BYTES	# Memory Address of (0, 0) for the cell write array
prev_arr:	.space	ARR_SIZE_BYTES	# Memory Address of (0, 0) for the cell previous state array
editing:	.word	1		# if on editing screen or not
camera_moved:	.word	0		# if camera moved during this frame
pan_speed:	.word	1		# number of pixels the camera moves when panning
template0:	.word	0 0 -999
template1:	.word	0 0 1 -1 -3 0 1 1 0 1 -1 0 -1 0 3 0 1 0 1 0 -999
template2:	.word   -1 0 1 1 1 0 0 -1 0 -1 -999
template3:	.word	0 0 -1 0 1 1 0 -2 1 0 -999
template4:	.word	0 0 -2 -1 0 2 -1 0 4 0 1 0 1 0 -999
template5:	.word	1 1 0 -1 0 -1 2 0 1 0 -1 -1 0 2 -4 2 0 1 -2 0 -999
template6:	.word	1 0 1 0 0 1 0 1 -2 0 0 -1 -1 0 -1 1 0 -3 0 -1 1 0 1 0 2 0 -999
template7:	.word	1 -1 -1 0 -1 0 0 1 0 1 1 0 1 0 -999
template8:	.word	0 0 0 -1 0 2 1 -1 1 -1 0 2 0 -1 -3 0 -1 -1 0 1 0 1 -999
template9:	.word	0 0 1 0 0 -1 1 0 -1 -1 -1 0 -1 1 -1 0 -1 0 0 1 1 0 0 1 1 -1 0 1 1 0 -999

# Macros

# pushes $ra to the stack
.macro push_ra
	sw	$ra, ($sp)
	addi	$sp, $sp, -4
.end_macro

# pops $ra from the stack
.macro pop_ra
	addi	$sp, $sp, 4
	lw	$ra, ($sp)
.end_macro

	.text
initialize:
	la	PREV_ARR, prev_arr	# load address of prev array
	la	EDITING_ARR, editing_arr# load address of editing array
	la	READ_ARR, read_arr	# load address of read array
	la	CHANGE_ARR, change_arr	# load address of change array
	
	li	CAMERA_X, 0		# make initial camera x offset to 0
	li	CAMERA_Y, 0		# make initial camera y offset to 0
	
	la	CHANGE_ARR, read_arr
	li	$a0, CURSOR_X
	li	$a1, CURSOR_Y
	la	$a2, template9		# place template 9 onto the canvas when the user initializes the program
	jal	invert_template

start_editing_loop:
	jal	clear_arrays		# clear the arrays
	la	CHANGE_ARR, read_arr	# write directly to the read array
	jal	load_editing		# copy previous canvas over
	li	$t0, 1
	sw	$t0, pan_speed		# max pan speed 1 pixel
editing_loop:
	jal	check_input		# check if there's input
	jal	editing_render		# render the screen
	
	lw	$t0, editing
	beq	$0, $t0, start_game_loop	# determine if still in editing mode, if not start the game
	j	editing_loop		# loop back to editing

start_game_loop:
	la	CHANGE_ARR, change_arr	# load change array address
	li	$t0, 1
	sw	$t0, camera_moved	# set camera as moved to force complete redraw
	li	$t0, 3
	sw	$t0, pan_speed		# set the pan speed to 3 pixels
game_loop:
	jal	check_input		# check if there is available input
	
	lw	$t0, camera_moved
	bne	$t0, $0, game_camera_moved	# if the camera moved, branch
	jal	game_render_fast	# use fast render since camera did not move
	j	game_apply_changes
game_camera_moved:
	bge	$t0, 2, game_reset_camera_moved	# if this is the 2nd generation after the camera moved, its okay to go back to fast render
	addi	$t0, $t0, 1
	sw	$t0, camera_moved	# reset camera moved to 0
	jal	game_render		# use full render since camera did move
	j	game_apply_changes
game_reset_camera_moved:
	sw	$0, camera_moved
	jal	game_render		# use full render since camera did move
game_apply_changes:	
	jal	apply_changes		# apply changes from change array to read array
	
	lw	$t0, editing
	bne	$0, $t0, start_editing_loop	# if in editing mode, go to the editing loop
	j	game_loop
	
exit:
	li	$v0, 10
	syscall

# check if input is available
check_input:
	# check if input is available
	lw	$t0, 0xffff0000
	beq	$t0, $0, exit_input	# if no input, skip input processing
# Controls:
# w 	(up)
# a 	(left)
# s 	(down)
# d 	(right)
# r	(reset canvas)
# f	(start/stop the game)
# e	(exit)
# space	(place/remove pixels)
# 0-9	load templates
process_input:
	lw	$t0, 0xffff0004		# load input
	beq	$t0, 119, pan_up	# w
	beq	$t0, 97, pan_left	# a
	beq	$t0, 115, pan_down	# s
	beq	$t0, 100, pan_right	# d
	beq	$t0, 114, reset_canvas	# r 
	beq	$t0, 102, toggle_editing# f 
	beq	$t0, 101, exit		# e
	beq	$t0, 32, insert_template# space
	beq	$t0, 48, change_template_id# 0
	beq	$t0, 49, change_template_id# 1
	beq	$t0, 50, change_template_id# 2
	beq	$t0, 51, change_template_id# 3
	beq	$t0, 52, change_template_id# 4
	beq	$t0, 53, change_template_id# 5
	beq	$t0, 54, change_template_id# 6
	beq	$t0, 55, change_template_id# 7
	beq	$t0, 56, change_template_id# 8
	beq	$t0, 57, change_template_id# 9
exit_input:
	jr	$ra

pan_up:
	li	$t0, 1
	sw	$t0, camera_moved
	lw	$t0, pan_speed
	sub	CAMERA_Y, CAMERA_Y, $t0
	bgt	CAMERA_Y, 0, exit_input
	addi	CAMERA_Y, CAMERA_Y, WINDOW_HEIGHT
	j	exit_input
pan_left:
	li	$t0, 1
	sw	$t0, camera_moved
	lw	$t0, pan_speed
	sub	CAMERA_X, CAMERA_X, $t0
	bgt	CAMERA_X, 0, exit_input
	addi	CAMERA_X, CAMERA_X, WINDOW_WIDTH
	j	exit_input
pan_down:
	li	$t0, 1
	sw	$t0, camera_moved
	lw	$t0, pan_speed
	add	CAMERA_Y, CAMERA_Y, $t0
	j	exit_input
pan_right:
	li	$t0, 1
	sw	$t0, camera_moved
	lw	$t0, pan_speed
	add	CAMERA_X, CAMERA_X, $t0
	j	exit_input
	
reset_canvas:
	lw	$t0, editing
	beq	$t0, $0, reset_canvas_exit
	push_ra
	jal	clear_all_arrays
	pop_ra
reset_canvas_exit:
	j	exit_input
	
toggle_editing:
	lw	$t0, editing
	bne	$t0, 0, toggle_editing_off
toggle_editing_on:
	li	$t0, 1
	sw	$t0, editing
	j	exit_input
toggle_editing_off:
	sw	$0, editing
	j	exit_input
	
change_template_id:
	subi	$t0, $t0, 48
	move	TEMPLATE_ID, $t0
	j	exit_input
	
insert_template:
	lw	$t0, editing
	beq	$t0, $0, insert_template_exit
	li	$a0, CURSOR_X
	li	$a1, CURSOR_Y
	push_ra
	jal	pixel_to_cell_coords	# returns the cell coordinates under the cursor in $v0, $v1
	pop_ra
	move	$a0, $v0
	move	$a1, $v1
	beq	TEMPLATE_ID, 1, insert_template_1
	beq	TEMPLATE_ID, 2, insert_template_2
	beq	TEMPLATE_ID, 3, insert_template_3
	beq	TEMPLATE_ID, 4, insert_template_4
	beq	TEMPLATE_ID, 5, insert_template_5
	beq	TEMPLATE_ID, 6, insert_template_6
	beq	TEMPLATE_ID, 7, insert_template_7
	beq	TEMPLATE_ID, 8, insert_template_8
	beq	TEMPLATE_ID, 9, insert_template_9

insert_template_0:
	push_ra
	jal	draw_dot
	pop_ra
	j	exit_input
	
insert_template_1:
	la	$a2, template1
	push_ra
	jal	invert_template
	pop_ra
	j	exit_input
	
insert_template_2:
	la	$a2, template2
	push_ra
	jal	invert_template
	pop_ra
	j	exit_input

insert_template_3:
	la	$a2, template3
	push_ra
	jal	invert_template
	pop_ra
	j	exit_input

insert_template_4:
	la	$a2, template4
	push_ra
	jal	invert_template
	pop_ra
	j	exit_input
	
insert_template_5:
	la	$a2, template5
	push_ra
	jal	invert_template
	pop_ra
	j	exit_input

insert_template_6:
	la	$a2, template6
	push_ra
	jal	invert_template
	pop_ra
	j	exit_input

insert_template_7:
	la	$a2, template7
	push_ra
	jal	invert_template
	pop_ra
	j	exit_input
	
insert_template_8:
	la	$a2, template8
	push_ra
	jal	invert_template
	pop_ra
	j	exit_input
insert_template_9:
	la	$a2, template9
	push_ra
	jal	invert_template
	pop_ra
	j	exit_input

insert_template_exit:
	j	exit_input
	
# sets the pixels of the display while editing
editing_render:
	li	$t4, 0			# i = pixel index = 0
editing_render_loop:
	li	$t3, WINDOW_WIDTH
	div	$t4, $t3		# divide pixel index by display width
	mfhi	$a0			# x coordinate will be the mod of the display width
	mflo	$a1			# y coordinate will be the dividend of the display width
	
	push_ra
	jal	pixel_to_cell_offset	# returns the cell offset in $v0
	pop_ra
	
	add	$t7, EDITING_ARR, $v0	# cell address from editing array
	lw	$t7, ($t7)		# load cell data from editing array
	
	push_ra
	jal	get_pixel_address	# returns the pixel address in $v0
	pop_ra
	
	beq	$t7, 1, edit_cell_alive
edit_cell_dead:
	li	$t5, BLACK
	sw	$t5, ($v0)
	j	edit_next_cell
edit_cell_alive:
	li	$t5, WHITE
	sw	$t5, ($v0)
edit_next_cell:	
	addi	$t4, $t4, 1		# i++
	blt	$t4, ARR_SIZE, editing_render_loop	# loop
edit_draw_cursor:
	li	$a0, CURSOR_X
	li	$a1, CURSOR_Y
	li	$a3, BLUE
	
	beq	TEMPLATE_ID, 1, edit_draw_template_1
	beq	TEMPLATE_ID, 2, edit_draw_template_2
	beq	TEMPLATE_ID, 3, edit_draw_template_3
	beq	TEMPLATE_ID, 4, edit_draw_template_4
	beq	TEMPLATE_ID, 5, edit_draw_template_5
	beq	TEMPLATE_ID, 6, edit_draw_template_6
	beq	TEMPLATE_ID, 7, edit_draw_template_7
	beq	TEMPLATE_ID, 8, edit_draw_template_8
	beq	TEMPLATE_ID, 9, edit_draw_template_9
edit_draw_cursor_dot:
	la	$a2, template0
	push_ra
	jal	draw_template
	pop_ra
	
	li	$v0, 32
	li	$a0, 10
	syscall				# sleep to have flashing effect
	
	li	$a0, CURSOR_X
	li	$a3, BLACK
	push_ra
	jal	draw_template
	pop_ra
	j	editing_exit_render
edit_draw_template_1:
	la	$a2, template1
	push_ra
	jal	draw_template
	pop_ra
	
	li	$v0, 32
	li	$a0, 10
	syscall				# sleep to have flashing effect
	
	li	$a0, CURSOR_X
	li	$a3, BLACK
	push_ra
	jal	draw_template
	pop_ra
	j	editing_exit_render
edit_draw_template_2:
	la	$a2, template2
	push_ra
	jal	draw_template
	pop_ra
	
	li	$v0, 32
	li	$a0, 10
	syscall				# sleep to have flashing effect
	
	li	$a0, CURSOR_X
	li	$a3, BLACK
	push_ra
	jal	draw_template
	pop_ra
	j	editing_exit_render
edit_draw_template_3:
	la	$a2, template3
	push_ra
	jal	draw_template
	pop_ra
	
	li	$v0, 32
	li	$a0, 10
	syscall				# sleep to have flashing effect
	
	li	$a0, CURSOR_X
	li	$a3, BLACK
	push_ra
	jal	draw_template
	pop_ra
	j	editing_exit_render
edit_draw_template_4:
	la	$a2, template4
	push_ra
	jal	draw_template
	pop_ra
	
	li	$v0, 32
	li	$a0, 10
	syscall				# sleep to have flashing effect
	
	li	$a0, CURSOR_X
	li	$a3, BLACK
	push_ra
	jal	draw_template
	pop_ra
	j	editing_exit_render
edit_draw_template_5:
	la	$a2, template5
	push_ra
	jal	draw_template
	pop_ra
	
	li	$v0, 32
	li	$a0, 10
	syscall				# sleep to have flashing effect
	
	li	$a0, CURSOR_X
	li	$a3, BLACK
	push_ra
	jal	draw_template
	pop_ra
	j	editing_exit_render
edit_draw_template_6:
	la	$a2, template6
	push_ra
	jal	draw_template
	pop_ra
	
	li	$v0, 32
	li	$a0, 10
	syscall				# sleep to have flashing effect
	
	li	$a0, CURSOR_X
	li	$a3, BLACK
	push_ra
	jal	draw_template
	pop_ra
	j	editing_exit_render
edit_draw_template_7:
	la	$a2, template7
	push_ra
	jal	draw_template
	pop_ra
	
	li	$v0, 32
	li	$a0, 10
	syscall				# sleep to have flashing effect
	
	li	$a0, CURSOR_X
	li	$a3, BLACK
	push_ra
	jal	draw_template
	pop_ra
	j	editing_exit_render
edit_draw_template_8:
	la	$a2, template8
	push_ra
	jal	draw_template
	pop_ra
	
	li	$v0, 32
	li	$a0, 10
	syscall				# sleep to have flashing effect
	
	li	$a0, CURSOR_X
	li	$a3, BLACK
	push_ra
	jal	draw_template
	pop_ra
	j	editing_exit_render
edit_draw_template_9:
	la	$a2, template9
	push_ra
	jal	draw_template
	pop_ra
	
	li	$v0, 32
	li	$a0, 10
	syscall				# sleep to have flashing effect
	
	li	$a0, CURSOR_X
	li	$a3, BLACK
	push_ra
	jal	draw_template
	pop_ra
	j	editing_exit_render
editing_exit_render:
	jr	$ra			# return	

# sets the pixels of the display while the game is running
game_render:
	li	$t4, 0			# i = pixel index = 0
game_render_loop:
	li	$t3, WINDOW_WIDTH
	div	$t4, $t3		# divide pixel index by display width
	mfhi	$a0			# pixel x coordinate will be the mod of the display width
	mflo	$a1			# pixel y coordinate will be the dividend of the display width
	
	push_ra
	jal	pixel_to_cell_offset	# returns the cell offset in $v0
	pop_ra
	
	add	$t6, PREV_ARR, $v0	# cell address from prev array
	add	$t7, READ_ARR, $v0	# cell address from read array
	lw	$t6, ($t6)		# load cell data from prev array
	lw	$t7, ($t7)		# load cell data from read array
	
	push_ra
	jal	get_pixel_address	# returns the pixel display address in $v0
	pop_ra
	
	beq	$t6, $0, game_previously_dead	# cell was previously dead
game_previously_alive:
	beq	$t7, 2, game_alive_to_alive	# 2 neighbors
	beq	$t7, 3, game_alive_to_alive	# 3 neighbors
	j	game_alive_to_dead		# dies otherwise
game_previously_dead:
	beq	$t7, 3, game_dead_to_alive	# 3 neighbors
	j	game_dead_to_dead		# stays dead otherwise
game_alive_to_dead:
	li	$t5, BLACK
	sw	$t5, ($v0)
	
	push_ra
	jal	pixel_to_cell_offset	# returns the cell offset in $v0
	pop_ra

	add	$t6, PREV_ARR, $v0
	sw	$0, ($t6)		# mark cell as dead
	
	push_ra
	jal	pixel_to_cell_coords
	pop_ra
	move	$a0, $v0		# x coord
	move	$a1, $v1		# y coord
	
	li	$a3, -1			# decrement neighbors
	push_ra
	jal	change_neighbors
	pop_ra
	j	game_next_cell

game_alive_to_alive:
	li	$t5, WHITE
	sw	$t5, ($v0)
	
	push_ra
	jal	pixel_to_cell_offset	# returns the cell offset in $v0
	pop_ra
	
	j	game_next_cell
game_dead_to_alive:
	li	$t5, WHITE
	sw	$t5, ($v0)
	
	push_ra
	jal	pixel_to_cell_offset	# returns the cell offset in $v0
	pop_ra

	add	$t6, PREV_ARR, $v0	# mark cell as alive
	li	$t3, 1
	sw	$t3, ($t6)
	
	push_ra
	jal	pixel_to_cell_coords
	pop_ra
	move	$a0, $v0		# x coord
	move	$a1, $v1		# y coord
	
	li	$a3, 1			# increment neighbors
	push_ra
	jal	change_neighbors
	pop_ra
	j	game_next_cell
game_dead_to_dead:
	li	$t5, BLACK
	sw	$t5, ($v0)
	
	j	game_next_cell
game_next_cell:
	addi	$t4, $t4, 1		# i++
	blt	$t4, ARR_SIZE, game_render_loop	# loop
exit_game_render:
	jr	$ra			# return
	
# sets the pixels of the display while the game is running (assuming camera has not moved)
game_render_fast:
	li	$t4, 0			# i = pixel index = 0
game_render_fast_loop:
	li	$t3, WINDOW_WIDTH
	div	$t4, $t3		# divide pixel index by display width
	mfhi	$a0			# pixel x coordinate will be the mod of the display width
	mflo	$a1			# pixel y coordinate will be the dividend of the display width
	
	push_ra
	jal	pixel_to_cell_offset	# returns the cell offset in $v0
	pop_ra
	
	add	$t6, PREV_ARR, $v0	# cell address from prev array
	add	$t7, READ_ARR, $v0	# cell address from read array
	lw	$t6, ($t6)		# load cell data from prev array
	lw	$t7, ($t7)		# load cell data from read array
	
	push_ra
	jal	get_pixel_address	# returns the pixel display address in $v0
	pop_ra
	
	beq	$t6, $0, game_previously_dead_fast	# cell was previously dead
game_previously_alive_fast:
	beq	$t7, 2, game_next_cell_fast	# 2 neighbors
	beq	$t7, 3, game_next_cell_fast	# 3 neighbors
	j	game_alive_to_dead_fast		# dies otherwise
game_previously_dead_fast:
	beq	$t7, 3, game_dead_to_alive_fast	# 3 neighbors
	j	game_next_cell_fast		# stays dead otherwise
game_alive_to_dead_fast:
	li	$t5, BLACK
	sw	$t5, ($v0)
	
	push_ra
	jal	pixel_to_cell_offset	# returns the cell offset in $v0
	pop_ra

	add	$t6, PREV_ARR, $v0
	sw	$0, ($t6)		# mark cell as dead
	
	push_ra
	jal	pixel_to_cell_coords
	pop_ra
	move	$a0, $v0		# x coord
	move	$a1, $v1		# y coord
	
	li	$a3, -1			# decrement neighbors
	push_ra
	jal	change_neighbors
	pop_ra
	j	game_next_cell_fast

game_dead_to_alive_fast:
	li	$t5, WHITE
	sw	$t5, ($v0)
	
	push_ra
	jal	pixel_to_cell_offset	# returns the cell offset in $v0
	pop_ra

	add	$t6, PREV_ARR, $v0	# mark cell as alive
	li	$t3, 1
	sw	$t3, ($t6)
	
	push_ra
	jal	pixel_to_cell_coords
	pop_ra
	move	$a0, $v0		# x coord
	move	$a1, $v1		# y coord
	
	li	$a3, 1			# increment neighbors
	push_ra
	jal	change_neighbors
	pop_ra
	j	game_next_cell_fast

game_next_cell_fast:
	addi	$t4, $t4, 1		# i++
	blt	$t4, ARR_SIZE, game_render_fast_loop	# loop
exit_game_render_fast:
	jr	$ra			# return

# adds the changes array to the read array
apply_changes:
	move	$t0, READ_ARR		# load read array
	move	$t1, CHANGE_ARR		# load change array
	move	$t5, PREV_ARR
	addi	$t4, $t0, 16384 # max address
apply_changes_loop:
	lw	$t2, ($t0)		# load read array data
	lw	$t3, ($t1)		# load change array data
	add	$t2, $t2, $t3		# calculate new data value
	sw	$0, ($t1)		# clear change array
	sw	$t2, ($t0)		# store new read value
	addi	$t0, $t0, 4		# move to next word
	addi	$t1, $t1, 4		# move to next word
	blt	$t0, $t4, apply_changes_loop
	jr	$ra			# return

# set $v0 to the display address of pixel ($a0, $a1)
# $a0 = x coordinate of pixel
# $a1 = y coordinate of pixel
get_pixel_address:
	# v0 = MEM + 4 * (x + y * width)
	mul	$v0, $a1, WINDOW_WIDTH	# v0 = y * WIDTH
	add	$v0, $a0, $v0		# x + $v0
	sll	$v0, $v0, 2		# word offset
	addi	$v0, $v0, MEM		# add display base address
	jr	$ra			# return

# sets $v0 and $v1 to the coordinates of the cell that represents a certain pixel location
# $a0 = x coordinate of pixel
# $a1 = y coordinate of pixel
pixel_to_cell_coords:
	add	$t0, $a0, CAMERA_X	# x coordinate of pixel + camera horizontal offset
	add	$t1, $a1, CAMERA_Y	# y coordinate of pixel + camera vertical offset
	
	bgt	$t0, 0, pixel_to_cell_coords_skip_x
	add	$t0, $t0, WINDOW_WIDTH
pixel_to_cell_coords_skip_x:
	bgt	$t0, 0, pixel_to_cell_coords_skip_y
	add	$t1, $t1, WINDOW_HEIGHT
pixel_to_cell_coords_skip_y:
	li	$t3, WIDTH
	div	$t0, $t3
	mfhi	$v0			# x coord % width
	li	$t3, HEIGHT
	div	$t1, $t3
	mfhi	$v1			# y coord % height
	jr	$ra			# return

# sets $v0 to the offset of the cell that should be displayed at a certain pixel location
# $a0 = x coordinate of pixel
# $a1 = y coordinate of pixel
pixel_to_cell_offset:
	add	$t0, $a0, CAMERA_X	# x coordinate of pixel + camera horizontal offset
	add	$t1, $a1, CAMERA_Y	# y coordinate of pixel + camera vertical offset
	
	bgt	$t0, 0, pixel_to_cell_offset_skip_x
	add	$t0, $t0, WINDOW_WIDTH
pixel_to_cell_offset_skip_x:
	bgt	$t1, 0, pixel_to_cell_offset_skip_y
	add	$t1, $t1, WINDOW_HEIGHT
pixel_to_cell_offset_skip_y:
	
	li	$t3, WIDTH
	div	$t0, $t3
	mfhi	$t0			# x coord % width
	li	$t3, HEIGHT
	div	$t1, $t3
	mfhi	$t1			# y coord % height
	
	# v0 = 4 * (CELL_X + CELL_Y * WIDTH)
	mul	$v0, $t1, WIDTH		# v0 = y * WIDTH
	add	$v0, $t0, $v0		# x + $v0
	sll	$v0, $v0, 2		# word offset
	jr	$ra			# return
		
# sets $v0 to the offset of ($a0, $a1)
# $a0 = x coordinate of cell (can be negative)
# $a1 = y coordinate of cell (can be negative)
get_cell_offset_safe:
	move	$t0, $a0
	move	$t1, $a1
	bgt	$t0, 0, get_cell_offset_safe_skip_x
	add	$t0, $t0, WIDTH
get_cell_offset_safe_skip_x:
	bgt	$t1, 0, get_cell_offset_safe_skip_y
	add	$t1, $a1, HEIGHT
get_cell_offset_safe_skip_y:

	li	$t3, WIDTH
	div	$t0, $t3
	mfhi	$t0			# x coord % width
	li	$t3, HEIGHT
	div	$t1, $t3
	mfhi	$t1			# y coord % height
	
	# v0 = 4 * (CELL_X + CELL_Y * WIDTH)
	mul	$v0, $t1, WIDTH		# v0 = CELL_Y * WIDTH
	add	$v0, $t0, $v0		# CELL_X + $v0
	sll	$v0, $v0, 2		# word offset
	jr	$ra			# return		
		
# sets $v0 to the offset of ($a0, $a1)
# $a0 = x coordinate of cell
# $a1 = y coordinate of cell
get_cell_offset:
	# v0 = 4 * (CELL_X + CELL_Y * WIDTH)
	mul	$v0, $a1, WIDTH		# v0 = CELL_Y * WIDTH
	add	$v0, $a0, $v0		# CELL_X + $v0
	sll	$v0, $v0, 2		# word offset
	jr	$ra			# return

# places all cells from editing array
load_editing:
	move	$t7, EDITING_ARR
	addi	$t6, $t7, ARR_SIZE_BYTES
load_editing_loop:
	lw	$t3, ($t7)
	beq	$t3, 0, load_editing_next	# skip since cell is dead
	sub	$t4, $t7, EDITING_ARR	# get offset
	div	$t4, $t4, 4		# remove word offset
	li	$t3, WIDTH
	div	$t4, $t3
	mfhi	$a0			# mod will be x coord
	mflo	$a1			# dividend will be y coord
	push_ra
	jal	edit_set_alive
	pop_ra
load_editing_next:
	addi	$t7, $t7, 4		# next cell
	blt	$t7, $t6, load_editing_loop
	jr	$ra			#return

# chamges the neighbors of a cell given its offset
# $a0 = x coordinate of cell
# $a1 = y coordinate of cell
# $a3 = change
change_neighbors:
	subi	$a1, $a1, 1
	push_ra
	jal	get_cell_offset_safe
	pop_ra
	add	$t0, $v0, CHANGE_ARR
	lw	$t1, ($t0)
	add	$t1, $t1, $a3
	sw	$t1, ($t0)
	
	addi	$a0, $a0, 1
	push_ra
	jal	get_cell_offset_safe
	pop_ra
	add	$t0, $v0, CHANGE_ARR
	lw	$t1, ($t0)
	add	$t1, $t1, $a3
	sw	$t1, ($t0)
	
	addi	$a1, $a1, 1
	push_ra
	jal	get_cell_offset_safe
	pop_ra
	add	$t0, $v0, CHANGE_ARR
	lw	$t1, ($t0)
	add	$t1, $t1, $a3
	sw	$t1, ($t0)
	
	addi	$a1, $a1, 1
	push_ra
	jal	get_cell_offset_safe
	pop_ra
	add	$t0, $v0, CHANGE_ARR
	lw	$t1, ($t0)
	add	$t1, $t1, $a3
	sw	$t1, ($t0)
	
	subi	$a0, $a0, 1
	push_ra
	jal	get_cell_offset_safe
	pop_ra
	add	$t0, $v0, CHANGE_ARR
	lw	$t1, ($t0)
	add	$t1, $t1, $a3
	sw	$t1, ($t0)
	
	subi	$a0, $a0, 1
	push_ra
	jal	get_cell_offset_safe
	pop_ra
	add	$t0, $v0, CHANGE_ARR
	lw	$t1, ($t0)
	add	$t1, $t1, $a3
	sw	$t1, ($t0)
	
	subi	$a1, $a1, 1
	push_ra
	jal	get_cell_offset_safe
	pop_ra
	add	$t0, $v0, CHANGE_ARR
	lw	$t1, ($t0)
	add	$t1, $t1, $a3
	sw	$t1, ($t0)
	
	subi	$a1, $a1, 1
	push_ra
	jal	get_cell_offset_safe
	pop_ra
	add	$t0, $v0, CHANGE_ARR
	lw	$t1, ($t0)
	add	$t1, $t1, $a3
	sw	$t1, ($t0)
	
	addi	$a0, $a0, 1
	addi	$a1, $a1, 1
	
	jr	$ra			#return

clear_arrays:
	la	$t0, read_arr		# Load read array
	la	$t1, change_arr		# Load change array
	la	$t2, prev_arr		# load prev array
	addi	$t3, $t0, ARR_SIZE_BYTES# Find maximum address for read array
clear_arrays_loop:
	sw	$0, ($t0)		# Clear read array index
	sw	$0, ($t1)		# Clear change array index
	sw	$0, ($t2)		# Clear prev array index
	addi	$t0, $t0, 4		# Move to next word
	addi	$t1, $t1, 4		# Move to next word
	addi	$t2, $t2, 4		# Move to next word
	blt	$t0, $t3, clear_arrays_loop	# Loop
	
	jr	$ra			# return
	
clear_all_arrays:
	la	$t0, read_arr		# Load read array
	la	$t1, change_arr		# Load change array
	la	$t2, prev_arr		# load prev array
	la	$t3, editing_arr
	addi	$t4, $t0, ARR_SIZE_BYTES# Find maximum address for read array
clear_all_arrays_loop:
	sw	$0, ($t0)		# Clear read array index
	sw	$0, ($t1)		# Clear change array index
	sw	$0, ($t2)		# Clear prev array index
	sw	$0, ($t3)		# Clear prev array index
	addi	$t0, $t0, 4		# Move to next word
	addi	$t1, $t1, 4		# Move to next word
	addi	$t2, $t2, 4		# Move to next word
	addi	$t3, $t3, 4		# Move to next word
	blt	$t0, $t4, clear_all_arrays_loop	# Loop
	
	jr	$ra			# return
	
# force a cell given coordinates to alive
# $a0 = x coordinate of cell
# $a1 = y coordinate of cell
edit_set_alive:
	push_ra
	jal	get_cell_offset_safe
	pop_ra
	add	$t0, $v0, EDITING_ARR
	li	$t1, 1
	sw	$t1, ($t0)
	
	add	$t0, $v0, PREV_ARR
	li	$t1, 1
	sw	$t1, ($t0)
	
	push_ra
	li	$a3, 1
	jal	change_neighbors
	pop_ra
	jr	$ra			#return

# force a cell given coordinates to alive
# $a0 = x coordinate of cell
# $a1 = y coordinate of cell
edit_set_dead:
	push_ra
	jal	get_cell_offset_safe
	pop_ra
	add	$t0, $v0, EDITING_ARR
	li	$t1, 0
	sw	$t1, ($t0)
	
	add	$t0, $v0, PREV_ARR
	sw	$0, ($t0)
	
	push_ra
	li	$a3, -1
	jal	change_neighbors
	pop_ra
	jr	$ra			#return

# inverts the cell at ($a0, $a1)
# $a0 = x coordinate of pixel
# $a1 = y coordinate of pixel
invert_cell:
	push_ra
	jal	get_cell_offset_safe
	pop_ra
	add	$t0, $v0, EDITING_ARR	# Get cell address
	lw	$t1, ($t0)
	beq	$t1, $0, invert_cell_alive# If dead, change it to alive
invert_cell_dead:
	push_ra
	jal	edit_set_dead
	pop_ra
	jr	$ra			# return
invert_cell_alive:
	push_ra
	jal	edit_set_alive
	pop_ra
	jr	$ra
	
# draws a dot centered at ($a0, $a1)
# $a0 = x coordinate of pixel
# $a1 = y coordinate of pixel
draw_dot:
	push_ra
	jal	invert_cell
	pop_ra
	jr	$ra			# return

# inverts a pixel template centered at ($a0, $a1)
# $a0 = x coordinate of pixel
# $a1 = y coordinate of pixel
# $a2 = address of template terminated with -999
invert_template:
	sw	$a0, ($sp)		# push x coord to stack
	addi	$sp, $sp, -4
	sw	$a1, ($sp)		# push y coord to stack
	addi	$sp, $sp, -4
	move	$t7, $a2		# x coordinate of pattern
	addi	$t6, $a2, 4		# y coordinate of pattern
	lw	$t2, ($t7)
invert_template_loop:
	lw	$t3, ($t6)
	add	$a0, $a0, $t2
	add	$a1, $a1, $t3
	
	push_ra
	jal	invert_cell
	pop_ra
	
	addi	$t7, $t7, 8		# move to next x coord
	addi	$t6, $t6, 8		# move to next y coord
	
	lw	$t2, ($t7)
	bne	$t2, -999, invert_template_loop
	
	addi	$sp, $sp 4
	lw	$a1, ($sp)		# pop y coord from stack
	addi	$sp, $sp 4
	lw	$a0, ($sp)		# pop x coord from stack
	
	jr	$ra			# return

# draws a pixel template centered at ($a0, $a1)
# $a0 = x coordinate of pixel
# $a1 = y coordinate of pixel
# $a2 = address of template terminated with -999
# $a3 = color
draw_template:
	sw	$a0, ($sp)		# push x coord to stack
	addi	$sp, $sp, -4
	sw	$a1, ($sp)		# push y coord to stack
	addi	$sp, $sp, -4
	move	$t0, $a2		# x coordinate of pattern
	addi	$t1, $a2, 4		# y coordinate of pattern
	lw	$t2, ($t0)
draw_template_loop:
	lw	$t3, ($t1)
	add	$a0, $a0, $t2
	add	$a1, $a1, $t3
	push_ra
	jal	get_pixel_address	# returns the pixel address in $v0
	pop_ra
	sw	$a3, ($v0)		# store color at pixel
	addi	$t0, $t0, 8		# move to next x coord
	addi	$t1, $t1, 8		# move to next y coord
	
	lw	$t2, ($t0)
	bne	$t2, -999, draw_template_loop
	
	addi	$sp, $sp 4
	lw	$a1, ($sp)		# pop y coord from stack
	addi	$sp, $sp 4
	lw	$a0, ($sp)		# pop x coord from stack
	
	jr	$ra			# return
