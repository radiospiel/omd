# Outline

This is where I start

## Simple Code

The following is a simple command:

```c
#include <stdio.h>
#include <stdlib.h>

int fib(int n) {
  return n < 3 ? 1 : fib(n-1) + fib(n-2);
}

int main(int argc, char** argv) {
  int n = atoi(argv[1]);
  printf("fibonacci of %d is %d\n", n, fib(n));
}
```
```output
fibonacci of 10 is 55
```

This code is pretty straight forward - but what does it communicate?

> generated via OMD from src/structure.md in 0.076 secs
