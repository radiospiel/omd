.PHONY: examples/mixed.md

all: readme examples/mixed.md

readme:
	rm -rf README.md*
	bin/omd process --clean README.omd

examples/mixed.md:
	bin/omd process --clean examples/mixed.omd

clean:
	git rm -rf README.md.data/ || true
	bin/omd process README.omd --clean
	git add README.omd README.md README.md.data

watch:
	git rm -rf README.md.data/ || true
	bin/omd watch README.omd --clean --display

format:
	rubocop -a bin lib

current_dir := $(subst $(HOME),~,$(shell pwd))
install:
	@echo "Please add $(current_dir)/bin to your path"
