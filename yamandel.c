#include <X11/Xlib.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

const int initialIterations = 100;
const int totalThreads = 8;
const double scalingfact = 0.1;
const double movingfact = 20.0;

typedef struct XWinDataStruct XWinData;
typedef struct PositionStruct Position;

struct ThreadCoord;

typedef struct {
  int startRow;
  int rows;
  pthread_mutex_t drawMutex;
  int doDraw;
  pthread_cond_t drawCond;
  struct ThreadCoord *coordinator;
  pthread_t thread;
  int finished;
  XWinData *winData;
  Position *position;
  unsigned int *image32;
} PlotThreadData;

struct ThreadCoord {
  int readyThreads;
  int maxThreads;
  pthread_mutex_t readyMutex;
  PlotThreadData *threads;
  pthread_cond_t continueCond;
};

extern void mandelbrotAsm(XWinData *winData, Position *position, int startRow,
                          int rows, unsigned int *image32);
extern void mandelbrotAsmV(XWinData *winData, Position *position, int startRow,
                          int rows, unsigned int *image32);

struct ThreadCoord *allThreads;

struct XWinDataStruct {
  Display *display;
  Drawable window;
  int width;
  int height;
  int depth;
  Visual *visual;
  GC gc;
  XImage *image;
  unsigned int *image32;
};

struct PositionStruct {
  double scale;
  double right;
  double down;
  int iterations;
  unsigned int *colorTable;
};

void debug(XWinData *winData, Position *position, int startRow, int rows) {
  int width = winData->width;
  printf("scale %f\n", position->scale);
  int height = winData->height;
  printf("height = %d\n", height);
  double c_re_left = -2.0 * position->scale + position->right;
  double c_im = ((startRow - height / 2.0) * 4.0 / height) * position->scale +
                position->down;
  printf("c_im = %f\n", c_im);
  printf("c_re_left = %f\n", c_re_left);
  double re_step = 4 * position->scale / (double)width;
  double im_step = 4 * position->scale / (double)height;
  printf("re_step = %f\n", re_step);
  printf("im_step = %f\n", im_step);
}

void calcMandelbrotPartInC(XWinData *winData, Position *position, int startRow,
                        int rows, unsigned int *image32) {
  int width = winData->width;
  int height = winData->height;
  int pixeladr = startRow * winData->width;
  double c_re_left = -2.0 * position->scale + position->right;
  double c_im = ((startRow - height / 2.0) * 4.0 / height) * position->scale +
                position->down;

  double re_step = 4 * position->scale / (double)width;
  double im_step = 4 * position->scale / (double)height;

  int endRow = startRow + rows;
  for (int row = startRow; row < endRow; row++) {
    double c_re = c_re_left;
    for (int col = 0; col < width; col++) {
      double x = 0, y = 0;
      int iteration = 0;

      double sqx = x * x;
      double sqy = y * y;

      while (sqx + sqy <= 4 && iteration < position->iterations) {
        double x_new = sqx - sqy + c_re;
        y = 2 * x * y + c_im;
        x = x_new;
        sqx = x * x;
        sqy = y * y;
        iteration++;
      }
      image32[pixeladr] = position->colorTable[iteration];
      c_re = c_re + re_step;
      pixeladr++;
    }
    c_im = c_im + im_step;
  }
}

long totalTime(struct timespec  time) {
        return 1000000000*time.tv_sec +  time.tv_nsec;
}

void calcMandelbrotPart(XWinData *winData, Position *position, int startRow,
                           int rows, unsigned int *image32) {
#ifdef COMPARE_TO_C
   struct timespec start, afterc, end;
//   debug(winData, position, startRow, rows);
   clock_gettime(CLOCK_THREAD_CPUTIME_ID , &start);
   calcMandelbrotPartInC(winData, position, startRow, rows, image32);
   clock_gettime(CLOCK_THREAD_CPUTIME_ID , &afterc);
#endif

   mandelbrotAsmV(winData, position, startRow, rows, image32);

#ifdef COMPARE_TO_C
   clock_gettime(CLOCK_THREAD_CPUTIME_ID , &end);
   printf("time of c calculations:%ld \n", totalTime(afterc)-totalTime(start));
   printf("time of asm calculations:%ld \n", totalTime(end)-totalTime(afterc));
#endif
}



void *threadedFunc(void *data) {
  PlotThreadData *threadData = (PlotThreadData *)data;
  struct ThreadCoord *coordinator = threadData->coordinator;
  while (!threadData->finished) {
    pthread_mutex_lock(&(threadData->drawMutex));
    while (!threadData->doDraw) {
      pthread_cond_wait(&(threadData->drawCond), &(threadData->drawMutex));
    }
    if (threadData->doDraw) {
      calcMandelbrotPart(threadData->winData, threadData->position,
                            threadData->startRow, threadData->rows,
                            threadData->image32);

      pthread_mutex_lock(&(coordinator->readyMutex));
      coordinator->readyThreads = coordinator->readyThreads + 1;
      pthread_cond_signal(&(coordinator->continueCond));
      pthread_mutex_unlock(&(coordinator->readyMutex));
      threadData->doDraw = False;
    }
    pthread_mutex_unlock(&(threadData->drawMutex));
  }
}

void initThreads() {
  struct ThreadCoord *threadCoord = malloc(sizeof(struct ThreadCoord));
  threadCoord->readyThreads = 0;
  threadCoord->maxThreads = totalThreads;
  pthread_mutex_init(&(threadCoord->readyMutex), NULL);
  pthread_cond_init(&(threadCoord->continueCond), NULL);
  threadCoord->threads = malloc(sizeof(PlotThreadData) * 4);
  for (int i = 0; i < totalThreads; i++) {
    threadCoord->threads[i].startRow = 0;
    threadCoord->threads[i].rows = 0;
    pthread_mutex_init(&(threadCoord->threads[i].drawMutex), NULL);
    pthread_mutex_lock(&(threadCoord->threads[i].drawMutex));
    threadCoord->threads[i].doDraw = False;
    pthread_cond_init(&(threadCoord->threads[i].drawCond), NULL);
    threadCoord->threads[i].finished = False;
    threadCoord->threads[i].coordinator = threadCoord;
    PlotThreadData *threadData = &(threadCoord->threads[i]);
    pthread_create(&(threadCoord->threads[i].thread), NULL, threadedFunc,
                   (void *)threadData);
    pthread_mutex_unlock(&(threadCoord->threads[i].drawMutex));
  }
  allThreads = threadCoord;
}

void triggerDrawingInThreads(XWinData *winData, Position *position,
                             unsigned int *image32) {
  pthread_mutex_lock(&(allThreads->readyMutex));
  allThreads->readyThreads = 0;
  pthread_mutex_unlock(&(allThreads->readyMutex));
  for (int t = 0; t < allThreads->maxThreads; t++) {
    allThreads->threads[t].winData = winData;
    allThreads->threads[t].position = position;
    allThreads->threads[t].image32 = image32;
    pthread_mutex_lock(&(allThreads->threads[t].drawMutex));
    allThreads->threads[t].doDraw = True;
    pthread_cond_signal(&(allThreads->threads[t].drawCond));
    pthread_mutex_unlock(&(allThreads->threads[t].drawMutex));
  }
}

void waitForThreads() {
  pthread_mutex_lock(&(allThreads->readyMutex));
  while (allThreads->readyThreads < allThreads->maxThreads) {
    pthread_cond_wait(&(allThreads->continueCond), &(allThreads->readyMutex));
  }
  pthread_mutex_unlock(&(allThreads->readyMutex));
}

XImage *drawMandelbrot(XWinData *winData, Position *position) {
  unsigned int *image32 = NULL;
  if (winData->image == NULL) {
    image32 = (unsigned int *)malloc(winData->width * winData->height * 4);
  } else {
    image32 = (unsigned int *)winData->image->data;
  }
  int width = winData->width;
  int height = winData->height;
  triggerDrawingInThreads(winData, position, image32);
  waitForThreads();
  if (winData->image == NULL) {
    XImage *ximage =
        XCreateImage(winData->display, winData->visual, winData->depth, ZPixmap,
                     0, (unsigned char *)image32, width, height, 32, 0);
    printf("image was null\n");
    XInitImage(ximage);
    printf("xinitimage done\n");
    winData->image = ximage;
  }
  return winData->image;
}

void recalcRowsForThreads(XWinData *winData) {
  int rows = winData->height;
  int rowsPerThread = (rows) / allThreads->maxThreads;
  int startRow = 0;
  printf("rows per thread %d\n", rowsPerThread);
  for (int t = 0; t < allThreads->maxThreads; t++) {
    allThreads->threads[t].startRow = startRow;
    if (startRow + rowsPerThread > rows) {
      allThreads->threads[t].rows = rows - startRow;
    } else {
      allThreads->threads[t].rows = rowsPerThread;
    }
    startRow = startRow + rowsPerThread;
  }
  allThreads->threads[allThreads->maxThreads - 1].rows =
      rows - allThreads->threads[allThreads->maxThreads - 1].startRow;
}

XImage *redraw(XWinData *winData, Position *position) {
  XImage *img = drawMandelbrot(winData, position);
  XEvent exposeEvent;
  memset(&exposeEvent, 0, sizeof(exposeEvent));
  exposeEvent.type = Expose;
  exposeEvent.xexpose.window = winData->window;
  XSendEvent(winData->display, winData->window, False, ExposureMask,
             &exposeEvent);

  return img;
}

void freeOldImage(XWinData *winData) {
  if (winData->image != NULL) {
    char *data = winData->image->data;
    XFree(winData->image);
    free(data);
    winData->image = NULL;
  }
}

XWinData *initDisplayWindow() {
  XWinData *winData = (XWinData *)malloc(sizeof(XWinData));
  Screen *screen;
  int s;

  winData->display = XOpenDisplay(NULL);
  if (winData->display == NULL) {
    fprintf(stderr, "Cannot open X display\n");
    exit(1);
  }
  s = DefaultScreen(winData->display);
  screen = ScreenOfDisplay(winData->display, s);
  unsigned long xAttrMask = CWBackPixel;
  XSetWindowAttributes xAttr;
  winData->window = XCreateWindow(
      winData->display, RootWindow(winData->display, s), 10, 10,
      (screen->width) / 2, (screen->height) / 2, 1, CopyFromParent,
      CopyFromParent, winData->visual, xAttrMask, &xAttr);
  XWindowAttributes windowAttributes;
  if (!XGetWindowAttributes(winData->display, winData->window,
                            &windowAttributes)) {
    fprintf(stderr, "No window attributes.\n");
    exit(1);
  }
  winData->depth = windowAttributes.depth;
  XSelectInput(winData->display, winData->window,
               ExposureMask | KeyPressMask | StructureNotifyMask);
  XMapWindow(winData->display, winData->window);
  winData->gc = XCreateGC(winData->display, winData->window, 0, 0);
  winData->width = (windowAttributes.width/4)*4;
  winData->height = windowAttributes.height;
  return winData;
}

int recalcColorTable(Position *position) {
  int max = position->iterations;
  if (position->colorTable != NULL) {
    free(position->colorTable);
  }
  position->colorTable = (unsigned int *)malloc(position->iterations * 4 + 128);
  for (int c = 0; c < position->iterations; c++) {
    unsigned char blue = (((max - (c * 2)) * 256) / (max)) & 0xff;
    unsigned char red = ((c / 2) * 256) / max & 0xff;
    unsigned char green = ((max - (c * 4)) * 256) / max & 0xff;
    position->colorTable[c] = blue + green * 256 + red * 256 * 256;
  }
}

int main(void) {
  XEvent e;
  Position *position = malloc(sizeof(Position));
  position->scale = 1.0;
  position->right = 0.0;
  position->down = 0.0;
  position->iterations = initialIterations;
  position->colorTable = NULL;
  recalcColorTable(position);
  XInitThreads();//LESSON - must be called if threads used - just because (even though we do not touch X from other threads)
  XWinData *winData = initDisplayWindow();
  initThreads();
  Drawable window = winData->window;
  Display *display = winData->display;

  Visual *visual = winData->visual;
  GC gc = winData->gc;

  int depth = winData->depth;
  recalcRowsForThreads(winData);
  XImage *ximage = drawMandelbrot(winData, position);
  while (1) {
    while (XPending(display) > 0) {

      XNextEvent(display, &e);
      if (e.type == Expose) {
        XPutImage(display, winData->window, gc, ximage, 0, 0, 0, 0,
                  winData->width, winData->height);

      }
      if (e.type == KeyPress) {

        printf("key = %d\n", e.xkey.keycode);
        KeySym ksym = XLookupKeysym(&(e.xkey),1);
         printf("ksym = %ld\n", ksym);
        if (e.xkey.keycode == 38) {
          position->scale = position->scale * (1 + scalingfact);
          ximage = redraw(winData, position);
        }
        if (e.xkey.keycode == 24) {
          position->scale = position->scale * (1 - scalingfact);
          ximage = redraw(winData, position);
        }
        if (e.xkey.keycode == 113) {
          position->right = position->right - position->scale / movingfact;
          ximage = redraw(winData, position);
        }
        if (e.xkey.keycode == 114) {
          position->right = position->right + position->scale / movingfact;
          ximage = redraw(winData, position);
        }
        if (e.xkey.keycode == 111) {
          position->down = position->down - position->scale / movingfact;
          ximage = redraw(winData, position);
        }
        if (e.xkey.keycode == 116) {
          position->down = position->down + position->scale / movingfact;
          ximage = redraw(winData, position);
        }
        if (e.xkey.keycode == 27) {
          position->iterations =
              position->iterations + position->iterations / 4;
          printf("iterations = %d\n", position->iterations);
          recalcColorTable(position);
          ximage = redraw(winData, position);
        }
        if (e.xkey.keycode == 41) {
                  position->iterations =
                      (position->iterations * 4 )/ 5;
                  printf("iterations = %d\n", position->iterations);
                  recalcColorTable(position);
                  ximage = redraw(winData, position);
        }
        break;
      }
      if (e.type == ConfigureNotify) {
        XConfigureEvent xce = e.xconfigure;
        if (xce.width != winData->width || xce.height != winData->height) {
          winData->width = (xce.width /4) *4;
          winData->height = xce.height;
          freeOldImage(winData);
          recalcRowsForThreads(winData);
          ximage = redraw(winData, position);
        }
      }
      XFlush(display);
    }
  }

  XCloseDisplay(display);
  return 0;
}
