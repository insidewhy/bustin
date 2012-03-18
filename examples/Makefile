include ../mk/flags.mk

.PHONY: test1 view clean

deps = $(wildcard ../*.d)
dmd ?= dmd
O = .obj

tests = test1

# test1: test1.d ${deps}
all: ${tests}

view: $(addprefix view-,${tests})

test1: ${O}/test1

${O}/%: %.d ${deps}
	${dmd} -od${O} -of$@ -I.. $^ ${llvm_link}

view-%: ${O}/%
	./$<

compiled-%: ${O}/%
	./$< 2>&1 | llvm-as | llvm-ld - -o $@

clean:
	rm -rf ${O}
