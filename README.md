
# Oh My Doc!

"Oh My Doc" –– or, short, `omd`, helps you write about code. It lets you embed both code blocks and their results into a Markdown document. This, I hope, should help people writing about and discussing code.

The input to *omd* still looks like and very much is markdown. In contrast to general markdown processing *omd* lets you embed both input data usually not processable by markdown.

*omd* acts as a preprocessor, converting enriched markdown into plain markdown, while taking care to process such input into a format that is generally compatibe with Markdown renderers, and embeds the generated output into the created target file.

Currently *omd* supports the following input:

- C language programs: they are compiled and executed; their output is embedded verbatim in the output;
- Graphviz dot scripts: they are rendered into images that then are embedded into the output;
- SQL commands: they are executed via a psql session; the output is rendered into a table.

With all of the above the input data can either be included in the rendered Markdown, or hidden.

## Security warning

Since the embedded scripts's functionality is by intention not crippled, a document, when run through *omd*, could be harmful. **You should therefore never open a OMD file that you didn't write yourself or inspected properly.**

You have been warned.

## Installation

1. Have a recent ruby version
2. Make sure bundler is installed: `gem install bundler`
3. Copy the script `bin/omd` into a location in your path.

*omd* uses a inline bunder setup; the first time you run it it will fetch some dependencies from rubygems.

<!--BREAK-->

# General use

## Command line usage

To process an input file run

    omd process [ --clean ] [ --display ] <src> <dest>

To continuously watch the input file for changes and rebuild when necessary run

    omd watch [ --clean ] [ --display ] <src> <dest>

Command line flags are:

- **`--clean`** *omd* manages a cache of command executions. The `--clean` command line argument makes sure to purge the cache, effectively rebuilding the entire document.
- **`--display`** start the *Marked 2* OSX application to display the generated result. *Marked 2* watches input document for changes, automatically refreshing whenever necessary.

<!--BREAK-->

# *omd* input files

In general, *omd* only deals with code blocks like the following, leaving everything else alone:

    ```{cc}
    #include <stdio.h>

    int main() {
      printf("Hello omd!\n"); return 0;
    }
    ```

The characters between `{` and `}` in the opening fence describe ** *omd* processing instructions**. They define the expected syntax in the code block. If supported by *omd* the embedded program is build and run, and it's output is captured and embedded into the resulting markdown file.

The following paragraphs describe various processing instructions.

## Comments

A comment block is not rendered in the output.

    ```{comment}
    This document is intended for processing with OMD  
    https://github.com/radiospiel/omd
    ```

## Processing a OMD document

OMD documents generally contain program code, which is executed in order to generate a Markdown file, which can then be viewed passively.

Since the embedded scripts are intentionally not crippled, it is very easy to set up a document that could, for example, delete your hard disk. **You should therefore never open a OMD file that you didn't write yourself or inspected properly.**

## C

The following block is compiling a C program and rendering both the source code and the output of the command. Lines starting with `@` are omitted from the output:

    ```{cc}
        @ #include <stdio.h>
        @ #include <stdlib.h>
        
        int fib(int n) {
          return n < 3 ? 1 : fib(n-1) + fib(n-2);
        }
    
        int main(int argc, char** argv) {
          int n = atoi(argv[1]);
          printf("Fibonacci number of %d is %d\n", n, fib(n));
        }
    ```

The result looks like this:

```cc
int fib(int n) {
  return n < 3 ? 1 : fib(n-1) + fib(n-2);
}

int main(int argc, char** argv) {
  int n = atoi(argv[1]);
  printf("Fibonacci number of %d is %d\n", n, fib(n));
}
```
```
Fibonacci number of 10 is 55
```

## Graphviz

The following block is being run through Graphviz`s `dot` command to generate a graph. The graph is then embedded as an image:

    ```{dot}
    digraph finite_state_machine {
	    rankdir=LR;
	    node [shape = square];
	    LR_0 -> LR_2 [ label = "foobar" ];
	    LR_0 -> LR_1 [ label = "SS(S)" ];
	    LR_1 -> LR_3 [ label = "S($start)" ];
    }
    ```

The result looks like this:

```dot
digraph finite_state_machine {
	rankdir=LR;
	node [shape = square];
	LR_0 -> LR_2 [ label = "foobar" ];
	LR_0 -> LR_1 [ label = "SS(S)" ];
	LR_1 -> LR_3 [ label = "S($start)" ];
}
```
![dot](./README.md.data/e5fe6234a5d360433079914af1e5d016.png)

## SQL

The following block is being executed as a SQL command:

    ```{sql}
    SELECT
      num,
      num * num AS square
    FROM
      generate_series(1, 6) as a(num)
    ```

The result looks like this:

```sql
SELECT
  num,
  num * num AS square
FROM
  generate_series(1, 6) as a(num)
```
|num | square|
|----|-------|
|1 | 1|
|2 | 4|
|3 | 9|
|4 | 16|
|5 | 25|
|6 | 36|
|(6 rows)|

The SQL code is executed as a SQL command via the `psql` command. A default installation of postgresql should be suitable to run this code. Generally the following commands should get you started:

```bash
  # on Ubuntu
  sudo apt-get install postgresql 
  
  # on OSX
  brew install postgresql
  
  # setup a default database
  createuser $(whoami)
  createdb $(whoami)
```

<!--BREAK-->

# Tips & Tricks

## Hiding parts or all of the source code

Lines in the source code portion starting with `@` are not included in the rendered markdown file.

Note that it is also possible to completely omit the command source code by prefixing the OMD processing instruction with an `@`, which works with all embedded commands.

    ```{@cc}
        #include <stdio.h>
        #include <stdlib.h>
        
        int fib(int n) {
          return n < 3 ? 1 : fib(n-1) + fib(n-2);
        }
    
        int main(int argc, char** argv) {
          int n = atoi(argv[1]);
          printf("Fibonacci number of %d is %d\n", n, fib(n));
        }
    ```

## Hint

When viewing the README.md file generated via omd in "Marked 2" you will notice that "Marked 2" replaces fenced code blocks with intendations with the last of those blocks in the input file. This seems to be an issue with "Marked 2". This should not affect the usefulness of the *omd* + *Marked 2* combination outside of this document though. 

```
Marked 2 has trouble with fenced code blocks with intendation.
This document is rendered incorrectly in Marked 2.
```