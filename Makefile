all: README.md examples/mixed.md

examples/mixed.md: examples/src/mixed.omd
	bin/omd process examples/src/mixed.omd examples/mixed.md --clean

README.md: examples/src/README.omd
	git rm -rf README.md.data/ || true
	bin/omd process src/README.omd README.md --clean
	git add README.md README.md.data

watch:
	git rm -rf README.md.data/ || true
	bin/omd watch src/README.omd README.md --clean --display

format:
	rubocop -a bin/omd
