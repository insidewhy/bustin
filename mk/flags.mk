# dmd only supports static libraries directly so just pass the linker flags
# through.. this works on linux at least
llvm_link = -L-L/usr/lib/llvm -L-lLLVM-3.0 -L-lstdc++ -L-ldl
