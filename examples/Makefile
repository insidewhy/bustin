include ../mk/flags.mk

deps = $(wildcard ../*.d)
dmd ?= dmd

test1: test1.d ${deps}
	${dmd} -od.obj -I.. $^ ${llvm_link}

clean:
	rm -f test1
