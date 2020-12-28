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
r - more iterations ( more colors - more details - more cpu intesive, but neede when zooming)
f - less iterations
cursors  - scroll left, up, right, down

## playing with cores

see yamandel.c and change this line
```
const int totalThreads = 16;
```
change line to use number of cores that You have.

## compare to C

the best is probably to change totalThreads to 1
as measuring is done per thread
then

 ```
make clean
make yamandel COMPARE=1
``` 
then run again and check console




## Results

- gcc vectorization seems to do a good job
- but it is not magic and some nasty corner cases should be written by hand  ( -fopt-info-vec-missed)
- it appears I could return after 6 months to a poorly written assembly code and 
refactor it
- normally it would make more sense to write such code in c using intrinsics, but I decided to play with plain assembly just for fun
  (the fun, however,  was `questionable`)

  
  
  

