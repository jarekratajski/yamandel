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


## Results

OK gcc vectorization seems to do good job.
 