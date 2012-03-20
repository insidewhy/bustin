.PHONY: capi examples

include mk/flags.mk

gen_files = gen/core.d gen/execution_engine.d gen/target.d

capi: ${gen_files}

examples: capi
	${MAKE} -C examples

${gen_files}: share/make-capi.pl
	@$< 2>/dev/null
