.PHONY: examples/mixed.md

all: examples/mixed.md

examples/mixed.md:
	bin/omd process examples/mixed.omd --output=examples/mixed.md --clean

clean:
	git rm -rf README.md.data/ || true
	bin/omd process README.omd --clean
	git add README.omd README.md README.md.data

watch:
	git rm -rf README.md.data/ || true
	bin/omd watch README.omd --clean --display

format:
	rubocop -a bin/omd
