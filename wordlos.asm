%define SCORE_POSITION              2620
%define SCORE_VALUE_POSITION        2634

%define KEYBOARD_ROW_POSITION1      2772 + 160 + 160
%define KEYBOARD_ROW_POSITION2      KEYBOARD_ROW_POSITION1 + 322
%define KEYBOARD_ROW_POSITION3      KEYBOARD_ROW_POSITION2 + 326

%define MESSAGE_POSITION            432
%define MESSAGE_COLOR_ERROR         0x04
%define MESSAGE_COLOR_SUCCESS       0x02

%define STATE_COLOR_EMPTY           0x78
%define STATE_COLOR_NOTINWORD       0x87
%define STATE_COLOR_INWORD          0xE7
%define STATE_COLOR_CORRECT         0x2F

%define KEYBOARD_COLOR_EMPTY        0x0F
%define KEYBOARD_COLOR_NOTINWORD    0x08
%define KEYBOARD_COLOR_INWORD       0x0E
%define KEYBOARD_COLOR_CORRECT      0x02

    org 0x0100

    ; Set 80-25 text mode
    mov ax, 0x0002
    int 0x10

    ; disable blinking chars (so we get all 16 background colors)
    mov ax, 0x1003
    mov bx, 0
    int 10h

    mov ax, 0xb800                  ; Segment for the video data
    mov es, ax

    cld

;;; GAME FLOW

start:
    ; Game title
    mov ah, 0x0F
    mov bp, c_title_string
    mov cx, 72
    call print_string

start_game:
    ; 1) reset board
    mov bp, game_words
    mov cx, 30                          ; 6 words with 5 characters
_reset_board:
    mov byte [bp], ' '
    inc bp
    loop _reset_board

    ; 2) reset letter status
    mov bp, game_words_state
    mov cx, 30                          ; 6 words with 5 characters
_reset_board_state:
    mov byte [bp], STATE_COLOR_EMPTY
    inc bp
    loop _reset_board_state

    ; 3) reset state
    mov al, 0
    mov byte [game_state_letter], al
    mov byte [game_state_word], al

    ; 4) reset keyboard states
    mov bp, game_keyboard_state
    mov cx, 26
_reset_keyboard:
    mov byte [bp], KEYBOARD_COLOR_EMPTY
    inc bp
    loop _reset_keyboard

    ; 5) randomize a word from the list
    mov ah, 0x00                        ; BIOS service to get system time
    int 0x1a                            ; AX contains the value

    mov bx, word [word_count]           ; get the amount of words
    mov ax, dx                          ; Copies the time fetched by interruption
    xor dx, dx                          ; Resets DX because DIV will use DXAX
    div bx                              ; AX = (DXAX) / bx ; DX = remainder
    mov ax, dx                          ; moves the current word index to AX
    mov bx, 5
    mul bx
    add ax, word_list 
    mov [game_selected_world], ax

main_loop:
    call draw_board
    call draw_keyboard

    ; clear message
    mov bp, c_message_empty
    mov ah, 0x08
    mov cx, MESSAGE_POSITION
    call print_string

    ; print score
    mov ah, 0x08
    mov bp, c_game_score
    mov cx, SCORE_POSITION
    call print_string

    mov ax, [game_score]
    mov di, SCORE_VALUE_POSITION
    mov byte [general_value], 0x0F
    call print_number

    ; Setting the cursor to the right position
    mov cx, [game_state_letter]            ; get current state (word:letter)
    mov al, 4
    mul cl
    add al, 31
    mov dl, al                      ; set current column

    mov al, 2
    mul ch
    add al, 4
    mov dh, al                      ; set current line

    mov ah, 02h                     ;Set cursor position function
    mov bh, 0                       ;Page number
    int 10h                         ;Interrupt call

check_input:
    mov ah, 0                       ; get keystroke
    int 0x16                        ; bios service to get input

    cmp al, 0x08                    ; 0x08 - backspace
    je del_letter  

    cmp al, 0x0d                    ; 0x0d - Enter
    je confirm_word                 ; for now, just loop

    cmp al, 0x1b	                ; escape key
    je exit

    ; Check if it's within the character range and check case
    ; A-Z: 0x41-0x5A
    ; a-z: 0x61-0x7A

    cmp al, 0x41
    jl check_input                  ; less than `A`
    cmp al, 0x7a
    jg check_input                  ; greater than `z`

    cmp al, 0x61
    jge add_letter                  ; it means it's already in range a-z

    cmp al, 0x5a
    jle lower_add_letter            ; it's within A-Z, needs lower case

    jmp check_input

lower_add_letter:
    add al, 0x20                    ; makes it lower case
add_letter:
    mov cl, byte [game_state_letter]
    cmp cl, 5
    je main_loop

    push ax

    mov ax, [game_state_letter]     ; copies the letter and the word
    mov byte [game_w], ah
    mov byte [game_l], al
    xor ax, ax                      ; resetting AX
    mov al, 5                       ; 5 letter per word
    mov bl, byte [game_w]           ; get current word
    mul bl                          ; multiply by the amount of words
    add al, byte [game_l]           ; adding the current letter
    mov bx, game_words              ; getting pointer to word list
    add ax, bx                      ; adding pointer to offset
    mov bp, ax                      ; setting to bp

    pop ax
    mov byte [bp], al
    mov al, byte [game_l]
    inc al
    mov ah, byte [game_w]
    mov byte [game_state_letter], al
    mov byte [game_state_word], ah

    jmp main_loop

del_letter:
    mov al, byte [game_state_letter]
    cmp al, 0                       ; if it's already the first letter, skip
    je main_loop

    mov ax, [game_state_letter]
    mov byte [game_w], ah
    mov byte [game_l], al
    xor ax, ax                      ; resetting AX
    mov al, 5                       ; 5 letter per word
    mov bl, byte [game_w]           ; get current word
    mul bl                          ; multiply by the amount of words
    add al, byte [game_l]           ; adding the current letter
    mov bx, game_words              ; getting pointer to word list
    add ax, bx                      ; adding pointer to offset
    dec ax
    mov bp, ax                      ; setting to bp
    
    mov byte [bp], 0x20             ; setting space, "empty letter"
    
    mov al, byte [game_state_letter]
    dec al                          ; go back to the previous position
    mov byte [game_state_letter], al

    jmp main_loop

confirm_word:
    mov al, byte [game_state_letter]
    cmp al, 5                       ; comparing if it's in the last letter
    jne check_input

    ; 1) compare if it's in the word list
    call check_valid_word
    cmp ah, 0                       ; if ah == 0, then word is valid
    jne error_not_in_dictionary

    ; 2) compare with the selected word and set state
    call update_word_state
    cmp ah, 1                       ; if ah == 1, then player found word
    je win_word

    ; 4) check current game status
    mov al, byte [game_state_word]
    cmp al, 5                       ; comparing if it's in the last word
    je lost_word

    ; 3) increment word
    mov al, byte [game_state_word]
    inc al
    mov byte [game_state_word], al
    mov byte [game_state_letter], 0

    jmp main_loop

error_not_in_dictionary:
    mov bp, c_message_invalid
    mov ah, MESSAGE_COLOR_ERROR
    call message_state
    jmp main_loop

win_word:
    call draw_board
    call draw_keyboard

    ; add score
    xor ah, ah
    mov al, byte [game_state_word]  ; get current word level
    shl ax, 1
    add ax, c_score_board
    mov bx, ax                      ; get address of current score info

    mov ax, [game_score]
    add ax, [bx]
    mov [game_score], ax

    ; print score
    mov di, SCORE_VALUE_POSITION
    mov byte [general_value], 0x0F
    call print_number

    ; show current score message
    xor ah, ah
    mov al, byte [game_state_word]  ; get current word level
    mov bx, 24                      ; 24 chars/bytes per message
    mul bx                          ; multiply the amount of chars by the current level to get right message

    add ax, c_message_win           ; add the address of the messages
    mov bp, ax
    mov ah, MESSAGE_COLOR_SUCCESS
    call message_state
    jmp start_game

lost_word:
    call draw_board

    mov bp, [game_selected_world]
    mov ah, MESSAGE_COLOR_SUCCESS
    mov cx, MESSAGE_POSITION + 36
    mov bx, 5
    call print_string_fixed

    mov bp, c_message_lost
    mov ah, MESSAGE_COLOR_ERROR
    call message_state
    jmp start_game


exit:
    int 0x20                        ; exit


;;; GAME FUNCTIONS

    ;
    ; Message state
    ; This will show a message, then wait for input
    ; Params:   BP - string addr
    ;           AH - message color
    ;
message_state:
    ; 1) print message
    mov cx, MESSAGE_POSITION
    call print_string

    ; 2) wait for input
    mov ah, 0                       ; get keystroke
    int 0x16                        ; bios service to get input

    ret

    ;
    ; Draws the keyboard with the current state for every letter
    ;
draw_keyboard:
    mov ah, 0
    mov al, 10
    mov bx, KEYBOARD_ROW_POSITION1
    call draw_keyboard_row

    mov ah, 10
    mov al, 19
    mov bx, KEYBOARD_ROW_POSITION2
    call draw_keyboard_row

    mov ah, 19
    mov al, 26
    mov bx, KEYBOARD_ROW_POSITION3
    call draw_keyboard_row
    ret

    ;
    ; Draws one row of the keyboard
    ; Params:   AH - range start
    ;           AL - range end
    ;           BX - position
draw_keyboard_row:
    mov di, bx                      ; set the screen position
    mov cx, ax                      ; copy range to CX to do the operations
    sub cl, ch                      ; CL contains the size of the range
    xor ch, ch                      ; now CX should the loop value
    mov al, ah                      ; bring the range start AX
    xor ah, ah
    mov bp, c_keyboard_rows         ; get the address of the string
    add bp, ax                      ; add the char offset
    
    mov bx, game_keyboard_state     ; keyboard state
    add bx, ax

_dkr_print:
    mov ah, byte [bx]
    mov al, byte [bp]
    stosw
    inc bp
    inc bx

    ; add some spaces
    mov al, ' '
    stosw
    mov al, ' '
    stosw

    loop _dkr_print

    ret
    
    ; Draws the board with the current game state
    ; go word by word and print the data
    ;
draw_board:
    mov cx, 6                       ; 6 words
_print_word:
    call print_word
    loop _print_word
    ret

    ;
    ; Print one word
    ; Params:   cx - current word
    ;
print_word:
    mov bx, cx                      ; save current word
    push cx
    mov cx, 5                       ; 5 letters
_print_letter:
    call print_letter
    loop _print_letter
    pop cx
    ret

    ;
    ; Prints one letter
    ; Params:   cx - current letter
    ;           bx - current word
    ;
print_letter:
    mov byte [game_l], cl
    mov byte [game_w], bl

    push cx                         ; draw_box function will change CX and BX, so we keep it
    push bx

    ; pointer to the letter in board
    ; used for both letter data and state
    push bx
    xor ax, ax                      ; resetting AX
    mov al, 5                       ; 5 letter per word
    mov bl, byte [game_w]           ; get current word
    dec bl                          ; bl -= 1
    mul bl                          ; multiply by the amount of words
    add al, byte [game_l]           ; adding the current letter
    dec al                          ; al -= 1
    mov [game_letter_ptr], ax       ; saving it to the pointer variable

    mov bx, game_words_state        ; getting pointer to the word/letters state
    add ax, bx                      ; adding pointer to offset
    mov bp, ax                      ; setting bp to the pointer
    xor ax, ax                      ; resetting ax
    mov ah, byte [bp]               ; getting the state data
    mov byte [game_letter_selected_color], ah
    pop bx

    push ax                         ; pushing the state as a color to the box function
    push 0x0103                     ; box dimensions 

    mov ax, 8
    mul cx
    add ax, 52
    push ax
    mov [game_pos], ax              ; saving current column to be used later

    mov ax, 160 * 2
    mul bx
    add ax, 160 * 2
    push ax                         ; vertical position
    
    add ax, [game_pos]              ; adding column to line to use later
    add ax, 2                       ; ONE character offset, middle of the box
    mov [game_pos], ax              ; saving current cursor position


    call draw_box
    add sp, 8                       ; returns the stack pointer, same as pop 4 times

    ; Print current letter
    mov ax, [game_letter_ptr]
    mov bx, game_words              ; getting pointer to word list
    add ax, bx                      ; adding pointer to offset
    mov bp, ax                      ; setting to bp

    mov ah, byte [game_letter_selected_color] ; setting the current state color
    mov al, byte [bp]               ; copying the character on the table to AL
    sub al, 0x20
    mov di, [game_pos]              ; adding the cursor position offset to DI
    mov [es:di], ax                 ; setting the current char in AX to video memory

    pop bx
    pop cx
    ret

    ;
    ; Check if the input word is in the list of words
    ; Return:   AH - 0 if word is valid
    ;
check_valid_word:
    mov cx, [word_count]            ; copy the amount of words

_check_valid_word_init:
    ; 1) get pointer to the current word
    xor ax, ax                      ; resetting AX
    mov al, 5                       ; 5 letter per word
    mov bl, byte [game_state_word]  ; get current word
    mul bl                          ; multiply by the amount of words
    add ax, game_words              ; ; adding the offset to the address
    mov [general_ptr1], ax          ; saving it to the pointer variable

    ; 2) get pointer to current word in list
    mov ax, 5                       ; 5 letter per word
    mov bx, cx
    dec bx
    mul bx                          ; multiply by the amount of words
    add ax, word_list               ; adding the offset to the address
    mov [general_ptr2], ax          ; saving it to the pointer variable

    ; 3) in order to compare letter by letter, you must
    push cx

    mov cx, 5                       ; 5 letters
_check_equal_letter:
    mov ax, [general_ptr1]          ; copy address of the first pointer
    add ax, cx                      ; adding current letter offset
    dec ax
    mov bp, ax
    xor ax, ax
    mov al, byte [bp]               ; get letter value
    push ax                         ; store letter from pointer 1

    mov ax, [general_ptr2]          ; copy address of the second pointer
    add ax, cx                      ; adding current letter offset
    dec ax
    mov bp, ax
    pop ax                          ; restore previous letter value
    mov ah, byte [bp]               ; get letter value

    cmp ah, al

    jne _check_equal_letter_continue
    loop _check_equal_letter        ; loop letters    
    ; ... if it got here, all words are the same, so it's good
    pop cx
    mov ah, 0
    ret
_check_equal_letter_continue:
    pop cx
    loop _check_valid_word_init     ; loop words
    ; ... if it got here, there are no similar words
    mov ah, 1
    ret

    ;
    ; Check the status letter by letter 
    ; Return:   AH:     0 if ok
    ;                   1 if all right
    ;
update_word_state:
    mov ax, 0
    mov [general_counter], ax
    ; get access to the current word
    mov ax, 5                       ; 5 letter per word
    mov bl, byte [game_state_word]  ; get current word
    mul bl                          ; multiply by the amount of words
    add ax, game_words              ; adding the offset to the address
    mov [general_ptr1], ax          ; saving it to the pointer variable

    ; get access to the current word's state
    mov ax, 5                       ; 5 letter per word
    mov bl, byte [game_state_word]  ; get current word
    mul bl                          ; multiply by the amount of words
    add ax, game_words_state        ; adding the offset to the address
    mov [general_ptr2], ax          ; saving it to the pointer variable

    ; for every letter:
    mov cx, 5
_letter_iteration:
    ; 1) check if the same index letter is the same, then green
    mov [general_value], cx         ; saving current main word letter
    mov ax, [general_ptr1]          ; pointer to the word
    add ax, cx                      ; add letter offset
    dec ax
    mov bp, ax
    mov ah, byte [bp]               ; copy letter to ah
    mov byte [game_l], ah           ; also store it on game_l

    push ax
    mov ax, [game_selected_world]   ; pointer to the word
    add ax, cx                      ; add letter offset
    dec ax
    mov bp, ax
    pop ax
    mov al, byte [bp]

    cmp ah, al                      ; check if the letters are the same
    je _update_set_green

    ; 2) check if any of the letters is right
    push cx
    mov cx, 5
_letter_in_word_iteration:
    mov ax, [game_selected_world]   ; pointer to the word
    add ax, cx                      ; add letter offset
    dec ax
    mov bp, ax
    mov al, byte [bp]
    mov ah, byte [game_l]

    cmp ah, al                      ; check if the letters are the same
    je _update_set_yellow
    
    mov ax, [general_ptr2]          ; pointer to the word
    add ax, [general_value]         ; add letter offset
    dec ax
    mov bp, ax
    mov byte [bp], STATE_COLOR_NOTINWORD   ; set 'letter not in word' state
    loop _letter_in_word_iteration

    ; set letter state
    mov bx, [general_ptr1]          ; pointer to the word
    add bx, [general_value]         ; add letter offset
    dec bx
    mov ah, byte [bx]               ; copy the character
    mov al, KEYBOARD_COLOR_NOTINWORD
    call set_letter_state
    pop cx
    jmp _update_loop

_update_set_yellow:
    ; set this letter state to yellow
    mov ax, [general_ptr2]          ; pointer to the word
    add ax, [general_value]         ; add letter offset
    dec ax
    mov bp, ax
    mov byte [bp], STATE_COLOR_INWORD  ; set 'letter in word' state
    
    ; set letter state
    mov bx, [general_ptr1]          ; pointer to the word
    add bx, [general_value]         ; add letter offset
    dec bx
    mov ah, byte [bx]               ; copy the character
    mov al, KEYBOARD_COLOR_INWORD
    call set_letter_state
    pop cx
    jmp _update_loop

    
_update_set_green:
    mov ax, [general_counter]
    inc ax
    mov [general_counter], ax
    ; set this letter state to green
    mov ax, [general_ptr2]          ; pointer to the word
    add ax, cx                      ; add letter offset
    dec ax
    mov bp, ax
    mov byte [bp], STATE_COLOR_CORRECT ; set 'letter in right position' state

    ; set letter state
    mov bx, [general_ptr1]          ; pointer to the word
    add bx, [general_value]         ; add letter offset
    dec bx
    mov ah, byte [bx]               ; copy the character
    mov al, KEYBOARD_COLOR_CORRECT
    push cx
    call set_letter_state
    pop cx
    jmp _update_loop

_update_loop:
    dec cx
    jnz _letter_iteration
    jmp _return

_return:
    mov ax, [general_counter]
    cmp ax, 5
    je _return_win
    mov ah, 0
    ret
_return_win:
    mov ah, 1
    ret

    ;
    ; Set Letter State function
    ; Params:   AH - character
    ;           AL - state
    ;
set_letter_state:
    mov cx, 26
    mov bp, c_keyboard_rows + 25
_find_letter_loop:
    mov bl, byte [bp]
    add bl, 32                      ; making it lower case to test with
    cmp bl, ah
    je _set_letter
    dec bp
    loop _find_letter_loop
    ret
_set_letter:
    mov bp, game_keyboard_state
    add bp, cx
    dec bp
    mov byte [bp], al
    ret

;;; BASE LIBRARY
%include "lib.asm"


;;; GAME GLOBAL VARIABLES
game_selected_world:        dw 0            ; pointer to the selected word in the list
game_state_letter:          db 0            ; current letter
game_state_word:            db 0            ; current word
game_words:
    db "     "
    db "     "
    db "     "
    db "     "
    db "     "
    db "     "

game_words_state:
    db STATE_COLOR_EMPTY,STATE_COLOR_EMPTY,STATE_COLOR_EMPTY,STATE_COLOR_EMPTY,STATE_COLOR_EMPTY
    db STATE_COLOR_EMPTY,STATE_COLOR_EMPTY,STATE_COLOR_EMPTY,STATE_COLOR_EMPTY,STATE_COLOR_EMPTY
    db STATE_COLOR_EMPTY,STATE_COLOR_EMPTY,STATE_COLOR_EMPTY,STATE_COLOR_EMPTY,STATE_COLOR_EMPTY
    db STATE_COLOR_EMPTY,STATE_COLOR_EMPTY,STATE_COLOR_EMPTY,STATE_COLOR_EMPTY,STATE_COLOR_EMPTY
    db STATE_COLOR_EMPTY,STATE_COLOR_EMPTY,STATE_COLOR_EMPTY,STATE_COLOR_EMPTY,STATE_COLOR_EMPTY
    db STATE_COLOR_EMPTY,STATE_COLOR_EMPTY,STATE_COLOR_EMPTY,STATE_COLOR_EMPTY,STATE_COLOR_EMPTY

game_keyboard_state:
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

game_score:                 dw 0            ; global game score

game_w:                     db 0            ; current word used in functions
game_l:                     db 0            ; current letter used in functions
game_pos:                   dw 0            ; current position used in functions
game_letter_ptr:            dw 0            ; pointer for the ltter in general
game_letter_selected_color: db 0            ;   ... selected state

general_ptr1:               dw 0            ; just general pointer
general_ptr2:               dw 0            ; just general pointer
general_value:              dw 0            ; just a general-use value
general_counter:            dw 0            ; just a general-use counter


;;; GAME CONSTANTS

c_title_string:         db "WORDLOS",0
c_game_score:           db "SCORE: ",0

; 24 chars
c_message_win:
    db "WHAT A SHOT! 100 POINTS",0
    db "  IMPRESSIVE! 50 POINTS",0
    db "  INCREDIBLE! 10 POINTS",0
    db "  PRETTY GOOD! 5 POINTS",0
    db "  GOOD ENOUGH! 2 POINTS",0
    db "          NICE! 1 POINT",0

c_message_invalid:
    db " WORD NOT IN DICTIONARY",0

c_message_lost:
    db "    THE WORD WAS: ",0

c_message_empty:
    db "                       ",0

c_keyboard_rows:
    db "QWERTYUIOPASDFGHJKLZXCVBNM"

c_score_board:
    dw 100
    dw 50
    dw 10
    dw 5
    dw 2
    dw 1


%include "words.asm"
