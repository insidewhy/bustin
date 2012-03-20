module bustin.capi.core;

// this module is generated using the Makefile, please read the README
public import bustin.gen.core;
import gen = bustin.gen.core; // for redirecting

LLVMValueRef LLVMConstString(string Str, LLVMBool DontNullTerminate = false) {
    return gen.LLVMConstString(Str.ptr, cast(uint)Str.length, DontNullTerminate);
}

// take advantage of some things like strings and ranges
LLVMTypeRef LLVMFunctionType(LLVMTypeRef ReturnType, LLVMTypeRef[] ParamTypes, LLVMBool IsVarArg = false) {
    return gen.LLVMFunctionType(ReturnType, ParamTypes.ptr, cast(uint)ParamTypes.length, IsVarArg);
}

LLVMValueRef LLVMBuildGEP(LLVMBuilderRef B, LLVMValueRef Pointer, LLVMValueRef[] Indices, const char *Name = "") {
    return gen.LLVMBuildGEP(B, Pointer, Indices.ptr, cast(uint)Indices.length, Name);
}
