all: README.md examples/mixed.md

examples/mixed.md: examples/src/mixed.omd
	bin/omd process examples/src/mixed.omd examples/mixed.md --clean

README.md: README.omd
	git rm -rf README.md.data/ || true
	bin/omd process README.omd --clean
	git add README.md README.md.data

watch:
	git rm -rf README.md.data/ || true
	bin/omd watch README.omd --clean --display

format:
	rubocop -a bin/omd
