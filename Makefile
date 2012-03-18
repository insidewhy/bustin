.PHONY: examples

include mk/flags.mk

examples:
	${MAKE} -C examples
