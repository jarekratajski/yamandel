CC=gcc
ifdef COMPARE
    CFLAGS=-DCOMPARE_TO_C -I. -Ofast -mtune=native -march=native -ffast-math
else
    CFLAGS=-I. -Ofast -march=native -mtune=native -ffast-math
endif
#debug
#CFLAGS=-I. -Ofast -march=native -ffast-math -g

yamandel: yamandel.o yamandel.c yasmandel.o yasmandelv.o
	$(CC) $(CFLAGS) yamandel.c -L/usr/X11R6/lib  -lpthread -lX11 yasmandel.o -o yamandel

reformat:
	clang-format -i yamandel.c

yasmandel.o: yasmandel.asm
	nasm -f elf64 -F dwarf -g yasmandel.asm
#nasm -f elf64 -F dwarf -g yasmandel.asm

yasmandelv.o: yasmandelv.asm
	nasm -f elf64 -F dwarf -g yasmandelv.asm

clean:
	rm -f $(binaries) *.o
	rm yamandel

