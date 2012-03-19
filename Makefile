.PHONY: capi examples

include mk/flags.mk

capi: gen/core.d

examples: capi
	${MAKE} -C examples

gen/core.d: share/make-capi.pl
	mkdir -p gen
	$< > $@
