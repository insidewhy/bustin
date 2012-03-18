.PHONY: examples

include mk/flags.mk

examples: capi.d
	${MAKE} -C examples

capi.d: share/make-capi.pl
	$< > $@
