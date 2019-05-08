
```
  ___  _       __  __         ____             _ 
 / _ \| |__   |  \/  |_   _  |  _ \  ___   ___| |
| | | | '_ \  | |\/| | | | | | | | |/ _ \ / __| |
| |_| | | | | | |  | | |_| | | |_| | (_) | (__|_|
 \___/|_| |_| |_|  |_|\__, | |____/ \___/ \___(_)
                      |___/                      
```

# Oh My Doc!

"Oh My Doc" –– or, short, `omd`, is a preprocessor which lets an author write markdown containing code. When preprocessing the document `omd` executes this code and embeds the results into the generated markdown output. For example, the logo above is generated via OMD's shell integration and the figlet command. Still, *omd's* input still looks like and very much is markdown.

The capability to embed code and its output should help you write about and discuss code or data. One could see `omd` as a server-less, lightweight, alternative to a Jypiter Notebook. 

Currently *omd* supports the following input:

- Shell commands
- C language programs: they are compiled and executed; their output is embedded verbatim in the output;
- Ruby programs: they are executed; their output is embedded verbatim in the output;
- Graphviz dot scripts: they are rendered into images that then are embedded into the output;
- SQL commands: they are executed via a psql session; the output is rendered into a table.

More details on omd processing instructions can be found below.

## Security warning

Since the embedded scripts's functionality is by intention not crippled, a document, when run through *omd*, could be harmful. **You should therefore never open a OMD file that you didn't write yourself or inspected properly.**

You have been warned.

## Installation

1. Have a recent ruby version
2. Make sure bundler is installed: `gem install bundler`
3. Copy the script `bin/omd` into a location in your path.

*omd* uses a inline bunder setup; the first time you run it it will fetch some dependencies from rubygems.

<!--BREAK-->

## Command line usage

To process an input file run

    omd process [ --clean ] [ --display ] <src> [ --output=<dest> ]

To continuously watch the input file for changes and rebuild when necessary run

    omd watch [ --clean ] [ --display ] <src> [ --output=<dest> ]

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


The characters between `{` and `}` in the opening fence describe ***omd* processing instructions**. They define the expected syntax in the code block. If a code block's processing instruction is supported by *omd* the embedded program is build and run, and its output is captured and embedded into the resulting markdown file.

## Controlling the display of the code block

When `omd` detects a code block it copies the code block into the output, followed by the code's output. It is possible to suppress either the entire source code block, leaving only the result in the output, by prepending the codeblock marker with a `@` character:

```
You should not see my source!
```

Alternatively, to hide some, but not all of the input, prepend these lines with an `@` character:

```cc
int main() {
  printf("The #include line should not be seen here.\n"); return 0;
}
```
```
The #include line should not be seen here.
```

## Comments

A comment block is not rendered in the output.

    ```{comment}
    This document is intended for processing with OMD  
    https://github.com/radiospiel/omd
    ```

## C: the `{cc}` processing instruction

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

## Graphviz: the `{dot}` processing instruction

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


## Shell code: the `{bash}` processing instruction

The following block is running a shell script:

    ```{bash}
		fortune all
    ```

The result looks like this:

```bash
fortune all
```
```
QOTD:
	"My life is a soap opera, but who gets the movie rights?"
```

## SQL: the `{sql}` processing instruction

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

## Hint

When viewing the README.md file generated via omd in "Marked 2" you will notice that "Marked 2" replaces fenced code blocks with intendations with the last of those blocks in the input file. This seems to be an issue with "Marked 2". This should not affect the usefulness of the *omd* + *Marked 2* combination outside of this document though. 

```
Marked 2 has trouble with fenced code blocks with intendation.
This document is rendered incorrectly in Marked 2.
```
