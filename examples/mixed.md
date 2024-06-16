
<!--TOC-->

# Outline

This is where I start

## Simple Code

The following is a simple command:


```cc
int fib(int n) {
  return n < 3 ? 1 : fib(n-1) + fib(n-2);
}

int main(int argc, char** argv) {
  int n = 20; // atoi(argv[1]);
  printf("Fibonacci number of %d is %d\n", n, fib(n));
}
```
```
Fibonacci number of 20 is 6765
```

This code is pretty straight forward - but what does it communicate?

Now some ruby:

```ruby
require 'benchmark'

data = "1" * 1000
n = 1000
Benchmark.bm do |x|
  x.report("+=") { s = ""; for i in 1..n; s += data; end }
  x.report("<<") { s = ""; for i in 1..n; s << data; end }
end
```
```ruby
       user     system      total        real
+=  0.020091   0.034472   0.054563 (  0.054956)
<<  0.000101   0.000053   0.000154 (  0.000155)
```

and some SQL:

```sql
SELECT *
FROM
  generate_series(1, 4) as a(aa),
  generate_series(1, 2) as b(b)
```
