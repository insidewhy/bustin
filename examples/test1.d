import bustin.capi.core;

int main() {
    // needs more substance!
    auto ctxt = LLVMGetGlobalContext();
    auto builder = LLVMCreateBuilderInContext(ctxt);

    auto mod = LLVMModuleCreateWithNameInContext("test1", ctxt);

    auto voidTy = LLVMVoidTypeInContext(ctxt);

    auto intTy = LLVMInt32TypeInContext(ctxt);

    ////////////////////////////////////////////////////////////////////////
    // TODO: reference to puts
    // LLVMTypeRef[1] putsTypes;

    // LLVMAddFunction(
    //     mod, "puts",
    //     LLVMFunctionType(voidTy, putsTypes.ptr, putsTypes.length, false));

    ////////////////////////////////////////////////////////////////////////
    // pump function
    LLVMTypeRef[1] pumpTypes;
    pumpTypes[0] = intTy;

    auto pumpFun = LLVMAddFunction(
        mod, "pump", LLVMFunctionType(voidTy, pumpTypes.ptr, pumpTypes.length, false));
    auto pumpBlock = LLVMAppendBasicBlock(pumpFun, "entry");
    LLVMPositionBuilderAtEnd(builder, pumpBlock);
    auto v1stack = LLVMBuildAlloca(builder, intTy, "fruitbat");
    auto v1 = LLVMConstInt(intTy, 14, false);
    auto ret1 = LLVMBuildAdd(builder, LLVMGetParam(pumpFun, 0), v1, "tmp");
    auto ret2 = LLVMBuildAdd(builder, ret1, v1, "tmp");
    LLVMBuildStore(builder, ret2, v1stack);
    // TODO: put it or something
    LLVMBuildRetVoid(builder);

    auto mainFun = LLVMAddFunction(
        mod, "main", LLVMFunctionType(voidTy, null, 0, false));
    auto mainBlock = LLVMAppendBasicBlock(mainFun, "entry");
    LLVMPositionBuilderAtEnd(builder, mainBlock);
    LLVMBuildRetVoid(builder);

    LLVMDumpModule(mod);

    return 0;
}
