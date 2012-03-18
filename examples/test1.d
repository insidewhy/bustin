import bustin.capi;

int main() {
    // needs more substance!
    auto ctxt = LLVMGetGlobalContext();
    auto builder = LLVMCreateBuilderInContext(ctxt);

    auto mod = LLVMModuleCreateWithNameInContext("test1", ctxt);

    auto voidTy = LLVMVoidTypeInContext(ctxt);

    auto intTy = LLVMInt32TypeInContext(ctxt);

    LLVMTypeRef[1] types;
    types[0] = intTy;

    auto funTy = LLVMFunctionType(voidTy, types.ptr, types.length, false);

    auto pumpFun = LLVMAddFunction(mod, "pump", funTy);

    auto block = LLVMAppendBasicBlock(pumpFun, "entry");

    LLVMPositionBuilderAtEnd(builder, block);

    auto v1stack = LLVMBuildAlloca(builder, intTy, "fruitbat");

    auto v1 = LLVMConstInt(intTy, 14, false);

    auto ret1 = LLVMBuildAdd(builder, LLVMGetParam(pumpFun, 0), v1, "tmp");
    auto ret2 = LLVMBuildAdd(builder, ret1, v1, "tmp");
    LLVMBuildStore(builder, ret2, v1stack);

    // TODO: put it or something
    LLVMBuildRetVoid(builder);

    LLVMDumpModule(mod);

    return 0;
}
