    org 0x0100

; Set 80-25 text mode
    mov ax, 0x0002
    int 0x10

    mov ax, 0xb800                  ; Segment for the video data
    mov es, ax

    cld

start:
    ; Game title
    mov ah, 0x67
    mov bp, title_string
    mov cx, 62
    call print_string

exit:
    int 0x20                        ; exit

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

title_string:       db "WORDLOS",0
