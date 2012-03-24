.PHONY: capi examples force_capi

mk_capi = ./share/make-capi.pl

include mk/flags.mk

gen_files = gen/core.d gen/execution_engine.d gen/target.d

capi: ${gen_files}

examples: capi
	${MAKE} -C examples

${gen_files}: ${mk_capi}
	@$< 2>/dev/null

force_capi:
	@rm -f gen/*.d
	@${mk_capi}
