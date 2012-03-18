.PHONY: capi examples

include mk/flags.mk

capi: capi/core.d

examples: capi/core.d
	${MAKE} -C examples

capi/core.d: share/make-capi.pl
	mkdir -p capi
	$< > $@
