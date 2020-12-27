global mandelbrotAsmV

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


mandelbrotAsmV:
        push r15
        push r14
        push r13
        push r12
        sub rsp, 128+8 ; needed for correct stack frame alignment (printf)
        mov qword  [rsp+positionOnStack], rsi ; position struct (scale, right, down)
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
        shl rax, 2
        mov rdx, rax ; rdx - address of bytes to write

        CVTPI2PD xmm7, [r10 +  winData_widthOffset] ;  (height, width)
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

        VBROADCASTSD ymm3, xmm4 ; (c_im,  c_im, c_im, c_im)

        ;movq r9, xmm3 ; ???
        ;debugDoubleValue  r9

        movq xmm1, [r13 + position_right_offset]
        movq xmm14, xmm6 ; scale
        movq xmm12, [rel  const_minus_2]
        mulsd xmm14, xmm12
        addsd xmm14, xmm1  ;xmm2 c_re_left -> was -2 OK

        ;movq r9, xmm14
        ;debugDoubleValue  r9


        movq xmm5, [rel  const_plus_4] ; again plus 4
        movlhps xmm5, xmm5  ;xmm5 has 4,4 - confirmed

         ;movq    r9, xmm5
         ;debugDoubleValue  r9

        ;MOVHPS   [rsp + tmpValStack], xmm11
        ;debugDoubleValue  qword [rsp+tmpValStack]

        VBROADCASTSD  ymm0, xmm6 ; (scale, scale, scale, scale)
        mulpd xmm5, xmm0 ;  confirmed
        divpd  xmm5, xmm7  ;(/ width / height  ;checking {0.0020833333333333333, 0.0037037037037037038}
        movhlps xmm11, xmm5


        VBROADCASTSD ymm7, xmm11 ; (im_step, im_step, im_step, im_step)
        VBROADCASTSD ymm6, xmm5; (re_step, re_step, re_step, re_step)


        mov r8d, dword  [rsp + rowsOnStack]
        add r8, r14 ; end row
        mov r12d, dword [r13 + position_iterations_offset]
        movq xmm15, [rel  const_plus_4] ; again plus 4


        movq xmm8, [rel  const_plus_4] ; again plus 4
        mov rdi, [r13 +position_colorTable_offset]
        mov r13, [rsp + imageOnStack]

         ;calculation for c_re_left
        vpxor  ymm8, ymm8, ymm8 ; (0,0,0,0)
        movq xmm8, xmm6 ;(0,0,0,re_step)
        VINSERTF128 ymm8,  ymm8, xmm6,0x1 ; (0,re_step,0,re_step)
        movlhps xmm8, xmm8  ; (0, re_step, re_step, re_step)
        ADDPD xmm8, xmm8; (0, re_step, 2re_step, 2re_step)
        ADDSD xmm8, xmm6;  (0, re_step, 2re_step, 3re_step)

        movlhps xmm14, xmm14
        VINSERTF128 ymm14, ymm14, xmm14, 0x1; (cr_left, cr_left, cr_left, cr_left)
        vaddpd  ymm8, ymm14 ; (cr_left, cr_left, cr_left, cr_left) +  (0, re_step, 2re_step, 3re_step)


        VMOVUPD ymm15,  [rel  const_pplus_4]
        VMOVUPD ymm14,  [rel  const_ones]
        ; small summary where we are
        ; xmm5  -  {im_step, re_step} - REMOVE
        ; --  REMOVED xmm11 {im_step}
        ; xmm14 - { , c_re_left}
        ; -- REMOVED xmm12 - { , c_im}
        ; xmm15  - 4
        ;  r14 - startRow (will use as index)
        ; r15  -width
        ;  r8 - endRow
        ; r12 iterations
        ; r13 image
        ;RDI colortable
        ;rdx pixeladddr

        ;new age
        ;ymm3 (c_im, c_im, c_im, c_im)
        ;ymm7 (im_step, im_step, im_step, im_step)
        ;ymm6 (re_step, re_step, re_step, re_step)
        ;ymm8; c_re_left   + (0, re_step, 2re_step, 3re_step)
        ;ymm15  - 4,4,4,4
        ;ymm14 - 1,1,1,1
        ;ymm13  - iterations (0)

rowsLoop:
        ;main rows  loop on r14 up to r8 (
        ; ymm2 - c_re
        VMOVUPD  ymm2, ymm8 ; start from c_re_left

         ;main cols loop on r11 up to r15
         xor r11,r11
colsLoop:
         vpxor ymm0,ymm0 ; x{0,0,0,0} -
         vpxor ymm1, ymm1; y{0,0,0,0}

        xor r10,r10 ; iteration
        vpxor ymm13,ymm13
iterationsLoop:
          VMOVUPD ymm4, ymm0 ; {x,x,x,x}
          VMOVUPD ymm5, ymm1; {y,y,y,y}

          VMULPD  ymm10, ymm4, ymm4 ;{x*x,x*x,x*x,x*x}
          VMULPD  ymm11, ymm5, ymm5 ; {y*y,y*y,y*y,y*y}



          vaddpd ymm12, ymm10, ymm11 ; x*x + y*y
          VCMPLTPD  ymm12, ymm15; ,  1h ;LT_OS (LT)  xompare with 4 /bug
          ; as long as there is at least one true (0xffffffff) we continue
          ; we stop if all is 0
          VTESTPD ymm12, ymm12; trick - will set ZF only if all bits were 0
          je endloop
          cmp r10,r12
          jg endloop
         VMOVUPD ymm0, ymm10 ; ymm0 = x*x
         VMOVUPD ymm1, ymm11; ymm1 = y*y

         vsubpd ymm0, ymm0, ymm1; x*x - y*y
         vaddpd ymm0, ymm0, ymm2; x*x -y*y + c_re

        vmulpd ymm1, ymm4, ymm5 ; x*y
        vaddpd ymm1, ymm1, ymm1; 2*x*y
        vaddpd ymm1, ymm3 ; 2*x*y + c_im

        VPAND ymm10, ymm12,ymm14
        vaddpd ymm13, ymm10
          inc r10
          jmp iterationsLoop
endloop:  ;-- here ended - rewriting (we need to store iterations better (in ymm integer
          ;we have in r10 iterations (ymm13 has better version)
          ; r13 img'
          ;RDI colortable
           ;rdx pixeladddr
          mov eax, dword [rdi+r10*4]
          mov dword [r13 + rdx], eax ;
          ;c_re = c_re+re_step;
          addsd xmm1, xmm5
          ;pixeladr++;
          add rdx, 10h

          ;inc col and test with r15
          add r11,4h
          cmp r11,r15
          vaddpd ymm2, ymm6 ; c_re + re_step
          jl colsLoop


          ;c_im = c_im  + im_step;
          addsd xmm12, xmm11
          ;inc row and test   r14 up to r8
          inc r14
          cmp r14,  r8
          vaddpd ymm3, ymm7
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
  const_pplus_4: dq 4.0,4.0,4.0,4.0
  const_ones: dq 1,1,1,1








