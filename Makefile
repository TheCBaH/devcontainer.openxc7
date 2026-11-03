TOOL ?=
.PHONY: submodule build
submodule:
	git -c safe.directory="$(CURDIR)" -c safe.directory="$(CURDIR)/*" submodule update --init --recursive --depth 1 $(if $(TOOL),sources/$(TOOL) $(if $(filter nextpnr,$(TOOL)),sources/prjxray-db))
build: submodule
	@for tool in $(if $(TOOL),$(TOOL),yosys nextpnr assembler); do bash scripts/build-tool.sh $$tool || exit $$?; done
