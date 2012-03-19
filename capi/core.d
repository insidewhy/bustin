module bustin.capi.core;

// this module is generated using the Makefile, please read the README
public import bustin.gen.core;
import gen = bustin.gen.core; // for redirecting

// take advantage of some things like default arguments and ranges
LLVMBasicBlockRef LLVMAppendBasicBlock(LLVMValueRef Fn, const char *Name = "") {
    return gen.LLVMAppendBasicBlock(Fn, Name);
}

LLVMValueRef LLVMConstString(constchar *Str, uint Length, LLVMBool DontNullTerminate = false) {
    return gen.LLVMConstString(Str, Length, DontNullTerminate);
}

LLVMTypeRef LLVMFunctionType(LLVMTypeRef ReturnType, LLVMTypeRef *ParamTypes, uint ParamCount, LLVMBool IsVarArg = false) {
    return gen.LLVMFunctionType(ReturnType, ParamTypes, ParamCount, IsVarArg);
}
