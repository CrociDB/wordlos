    ;
    ; Print string function
    ; Params:   AH - background/foreground color
    ;           BP - string addr
    ;           CX - position/offset
    ;
print_string:
    mov di, cx                      ; Adds offset to DI
    mov al, byte [bp]               ; Copies the char to AL (AH already contains color data)
    cmp al, 0                       ; If the char is zero, string finished
    jz _0                           ; ... return
    stosw
    add cx, 2                       ; Adds more 2 bytes the offset
    inc bp                          ; Increments the string pointer
    jmp print_string                ; Repeats the rest of the string
_0:
    ret


    ;
    ; Print number function
    ; Params:   AX              - num value
    ;           DI              - position/offset
    ;           general_value   - background/foreground color
    ;
print_number:
    cmp ax, 0
    jne _init
    mov cx, 1
    push 0
    jmp _print
_init:
    xor cx, cx
_get_unit:
    cmp ax, 0
    je _print
    xor dx, dx
    mov bx, 10
    div bx
    xor bx, bx
    mov bl, dl
    push bx
    inc cx
    jmp _get_unit

_print:
    pop ax
    add al, '0'                     ; Add char `0` to value
    mov ah, byte [general_value]    ; Copy color info
    stosw
    loop _print
_p_exit:
    ret


    ;
    ; Draw box function
    ; Params:   [bp+2] - row offset
    ;           [bp+4] - column offset
    ;           [bp+6] - box dimensions
    ;           [bp+8] - char/Color
    ;
draw_box:
    mov bp, sp                      ; Store the base of the stack, to get arguments
    xor di, di                      ; Sets DI to screen origin
    add di, [bp+2]                  ; Adds the row offset to DI

    mov dx, [bp+6]                  ; Copy dimensions of the box
    mov ax, [bp+8]                  ; Copy the char/color to print
    mov bl, dh                      ; Get the height of the box

    xor ch, ch                      ; Resets CX
    mov cl, dl                      ; Copy the width of the box
    add di, [bp+4]                  ; Adds the line offset to DI
    rep stosw

    add word [bp+2], 160            ; Add a line (180 bytes) to offset
    sub byte [bp+7], 0x01           ; Remove one line of height - it's 0x0100 because height is stored in the msb
    mov cx, [bp+6]                  ; Copy the size of the box to test
    cmp ch, 0                       ; Test the height of the box
    jnz draw_box                    ; If not zero, draw the rest of the box
    ret