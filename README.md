# Mandelbrot plot in Assembly / C

This is my exercise in writing assembly. Just for fun / training.
Code is neither good nor optimal (In c and asm).

I used AVX and SSE - basically trying to do mandelbrot plot that would draw fast enough on my threadripper machine.
There exists faster algotihms but I started with classical one.


Needs XWindow.


#usage

```
make
./yamandel
```
## keyboard
q - zoom in
a - zoom out
r - more iterations( colors)
f - lest iterations
cursors  - scroll



## compare to C
add at top of yamandel.c 
 ```
#define COMPARE_TO_C 1
``` 
then
```
make clean
make
```
## playing with cores
```
const int totalThreads = 16;
```
change line to use number of cores that You have.



## Strange experiences
First I did algorithm in C. 

I have expected that gcc with `-O3` and `arch native` would beat my handwritten assembly.

Results I  get are however strange:
 
 time of c calculations:     5454471
  
 time of asm calculations:2895857
 
I have analyzed that is gcc producing and  realized that althogh it is using SSE and AVX instrictions
   it does almost exlusively using scalar operations (no real vectorization).
This is disappointment. Maybe I did sth wrong (yet another switch?).

My assembly code is naive translation of c code. I tried to use minial vectorization but it did not really work
I was strugling too much with errors (typically messing which part of xmm is x which y etc.)
At the end my asm is not very smart in using xmm and in fact obviously is suboptimal - I was happy that it works...

So I am even more surprised by the results - 
asm code seems to beat ggc almost 2 to 1...
Why?
 - did I do sth wrong in c , gcc options?
 - did I do sth wrong in asm (simplification?)
 - ?
  

    
 
 
 