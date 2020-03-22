global mandelbrotAsm

extern printf, getline, stdin

%define winDataOnStack  1*8h
%define positionOnStack   2*8h
%define startRowOnStack   3*8h
%define rowsOnStack   4*8h
%define imageOnStack   5*8h

%define tmpValStack 6*8

%define winData_widthOffset 2*8h
%define winData_heightOffset 2*8h + 4

%define position_scale_offset 0*8h
%define position_right_offset 1*8h
%define position_down_offset 2*8h
%define position_iterations_offset 3*8h;
%define position_colorTable_offset 4*8h


%macro  debugIntValue 1

                mov rsi, %1
                lea rdi, [rel debugIntValMsg]
                sub  rsp, 64   ; stack space
                xor  rax, rax
                call  printf  WRT ..plt
                add rsp, 64

%endmacro

%macro  debugDoubleValue 1

                push rax
                push rsi
                push rdi
                push r8
                push r9

                mov rax,rax
                mov rsi, %1
                movq xmm0, %1
                ;movlps  xmm0, qword %1
                mov rax,1
                lea rdi, [rel debugDoubleValMsg]
                sub  rsp, 64+8   ; stack space
                call  printf  WRT ..plt
                add rsp, 64+8

                pop r9
                pop r8
                pop rdi
                pop rsi
                pop rax

%endmacro

section .text

;https://wiki.osdev.org/System_V_ABI
 ; x86 64 calling conv RDI, RSI, RDX, RCX, R8, R9, [XYZ]MM0–7
 ; callee saves r12-r15, rbx,rbp


mandelbrotAsm:
        push r15
        push r14
        push r13
        push r12
        sub rsp, 128+8 ; needed for correct stack frame alignment (printf)
        mov qword  [rsp+positionOnStack], rsi
        mov qword  [rsp +winDataOnStack], rdi
        mov dword  [rsp +startRowOnStack], edx
        mov dword  [rsp +rowsOnStack], ecx
        mov [rsp +imageOnStack], r8



        xor r15,r15
        xor r14,r14
        ;xor r12,r12
        mov r10, [rsp + winDataOnStack]
        mov r15d, dword [r10 +  winData_widthOffset]
        ;mov r15h, dword[r10  +   winData_widthOffset]
        mov r14d, dword [rsp +startRowOnStack]
        mov r13,  [ rsp + positionOnStack]

        mov rax, r14
        mul r15
        mov rdx, rax

        CVTPI2PD xmm7, [r10 +  winData_widthOffset] ; width / height in xmm7
        movhlps xmm4, xmm7 ; height in xmm4
        movhlps xmm3, xmm7 ; height in xmm3

        ;movq r9, xmm4 ;xmm was 1920 - >ok
        ;debugDoubleValue  r9

        movq xmm5, [rel  const_minus_2]
        divsd xmm4, xmm5 ; height / -2.0

        CVTSI2SD xmm5, r14 ; startRow


        addsd  xmm4, xmm5 ;startrow + height /-2.0

        movq xmm5, [rel  const_plus_4]
        mulsd xmm4, xmm5  ; * 4.0
        divsd xmm4, xmm3 ; xmm4 almost  c_im_ (/height)
        movq xmm6, [r13  + position_scale_offset] ; scale
        mulsd xmm4, xmm6
        movq xmm5, [ r13 + position_down_offset] ; down
        addsd xmm4, xmm5 ; c_im  ; xmm4 was -2 -> OK!

        movq r9, xmm4
        movq xmm12, r9

        ;movq r9, xmm4 ; ???
        ;debugDoubleValue  r9

        movq xmm1, [r13 + position_right_offset]
        movq xmm14, xmm6 ; scale
        movq xmm3, [rel  const_minus_2]
        mulsd xmm14, xmm3
        addsd xmm14, xmm1  ;xmm2 c_re_left -> was -2 OK

        ;movq r9, xmm14
        ;debugDoubleValue  r9


        movq xmm5, [rel  const_plus_4] ; again plus 4
        movlhps xmm5, xmm5  ;xmm5 has 4,4 - confirmed

         ;movq    r9, xmm5
         ;debugDoubleValue  r9

        ;MOVHPS   [rsp + tmpValStack], xmm11
        ;debugDoubleValue  qword [rsp+tmpValStack]

        movlhps xmm6, xmm6 ; scale, scale
        mulpd xmm5, xmm6 ; confirmed
        divpd  xmm5, xmm7  ;(/ width / height  ;checking {0.0020833333333333333, 0.0037037037037037038}
        movhlps xmm11, xmm5



        mov r8d, dword  [rsp + rowsOnStack]
        add r8, r14
        mov r12d, dword [r13 + position_iterations_offset]
        movq xmm15, [rel  const_plus_4] ; again plus 4


        movq xmm8, [rel  const_plus_4] ; again plus 4
        mov rdi, [r13 +position_colorTable_offset]
        mov r13, [rsp + imageOnStack]
        ; small sumarry where we are
        ; xmm5  -  {im_step, re_step}
        ; xmm11 {im_step}
        ; xmm14 - { , c_re_left}
        ; xmm12 - { , c_im}
        ; xmm15  - 4
        ;  r14 - startRow (will use as index)
        ; r15  -width
        ;  r8 - endRow
        ; r12 iterations
        ; r13 image
        ;RDI colortable
        ;rdx pixeladddr



rowsLoop:
        ;main rows  loop on r14 up to r8 (
         ; xmm1 - c_re
         movq xmm1, xmm14  ; start from c_re_left

         ;main cols loop on r11 up to r15
         xor r11,r11
colsLoop:
         xorps xmm0,xmm0  ; {x,y}

        xor r10,r10 ; iteration
iterationsLoop:
          movhlps  xmm8, xmm0 ; y in xmm 8
          movlhps  xmm8, xmm0 ; {y, x} in xmm 8

          movhlps  xmm9, xmm8 ; y in xmm 9
          movlhps  xmm9, xmm8 ; {x, y} in xmm 9

          mulpd xmm0,xmm0  ; double sqx = x*x; double sqy = y*y;
          xorps xmm2, xmm2
          VHADDPD   xmm2, xmm0, xmm2 ; xmm2 lower has sqx  + sqy
          CMPNLTSD   xmm2, xmm15  ; xompare with 4 /bug
          movq rax, xmm2
          cmp rax, 0xffffffff
          je endloop
          cmp r10,r12
          jg endloop
          mulpd xmm9,xmm8;  {x*y,x*y}
          addsd xmm9,xmm9; *2
          addsd xmm9, xmm12; x*y*2 + c_im (y)
          ; sqx-sqy+c_re
          pxor xmm10,xmm10
          HSUBPD  xmm0, xmm10; probably{ --, x*x -y*y}
          ADDSD xmm0, xmm1 ; +c_re  ; x_new


          movlhps xmm0, xmm9
          inc r10
          jmp iterationsLoop
endloop:
          ;we have in r10 iterations
          ; r13 img'
          ;RDI colortable
           ;rdx pixeladddr
          mov eax, dword [rdi+r10*4]
          mov dword [r13 + rdx], eax ;
          ;c_re = c_re+re_step;
          addsd xmm1, xmm5
          ;pixeladr++;
          adc rdx,4h

          ;inc col and test with r15
          inc r11
          cmp r11,r15
          jl colsLoop


          ;c_im = c_im  + im_step;
          addsd xmm12, xmm11
          ;inc row and test   r14 up to r8
          inc r14
          cmp r14,  r8
          jl rowsLoop


        add rsp, 128+8
        pop r12
        pop r13
        pop r14
        pop r15
        ret

section .rodata
  debugIntValMsg: db "Deine int val = %d",10,0
  debugDoubleValMsg: db "Deine double val =  %f",10,0
  const_minus_2: dq -2.0
  const_plus_2: dq 2.0
  const_plus_4: dq 4.0








