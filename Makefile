CC=gcc
ifdef COMPARE
    CFLAGS=-DCOMPARE_TO_C -I. -Ofast -march=native -ffast-math
else
    CFLAGS=-I. -Ofast -march=native -ffast-math
endif
#debug
#CFLAGS=-I. -Ofast -march=native -ffast-math -g

yamandel: yamandel.o yamandel.c yasmandel.o
	$(CC) yamandel.c -L/usr/X11R6/lib  -lpthread -lX11 yasmandel.o -o yamandel

reformat:
	clang-format -i yamandel.c

yasmandel.o: yasmandel.asm
	nasm -f elf64 yasmandel.asm
#nasm -f elf64 -F dwarf -g yasmandel.asm


clean:
	rm -f $(binaries) *.o
	rm yamandel

