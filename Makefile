.PHONY: examples

include mk/flags.mk

examples: capi/core.d
	${MAKE} -C examples

capi/core.d: share/make-capi.pl
	mkdir -p capi
	$< > $@
