import bustin.capi.core;

// http://pastebin.com/Skgrvajg

int main() {
    auto ctxt = LLVMGetGlobalContext();
    auto builder = LLVMCreateBuilderInContext(ctxt);
    auto mod = LLVMModuleCreateWithNameInContext("test1", ctxt);

    auto voidTy = LLVMVoidTypeInContext(ctxt);
    auto intTy = LLVMInt32TypeInContext(ctxt);

    ////////////////////////////////////////////////////////////////////////
    // reference to external puts function from c library
    LLVMTypeRef[1] putsTypes;
    putsTypes[0] = LLVMPointerType(LLVMInt8TypeInContext(ctxt), 0);

    auto putsFun = LLVMAddFunction(
        mod, "puts",
        LLVMFunctionType(voidTy, putsTypes.ptr, putsTypes.length, false));

    ////////////////////////////////////////////////////////////////////////
    // pump function
    LLVMTypeRef[1] pumpTypes;
    pumpTypes[0] = intTy;

    auto pumpFun = LLVMAddFunction(
        mod, "pump", LLVMFunctionType(voidTy, pumpTypes.ptr, pumpTypes.length, false));
    auto pumpBlock = LLVMAppendBasicBlock(pumpFun, "");
    LLVMPositionBuilderAtEnd(builder, pumpBlock);
    auto v1stack = LLVMBuildAlloca(builder, intTy, "fruitbat");
    auto v1 = LLVMConstInt(intTy, 14, false);
    auto ret1 = LLVMBuildAdd(builder, LLVMGetParam(pumpFun, 0), v1, "");
    auto ret2 = LLVMBuildAdd(builder, ret1, v1, "");
    LLVMBuildStore(builder, ret2, v1stack);
    // TODO: put it or something
    LLVMBuildRetVoid(builder);

    auto mainFun = LLVMAddFunction(
        mod, "main", LLVMFunctionType(intTy, null, 0, false));
    auto mainBlock = LLVMAppendBasicBlock(mainFun, "");
    LLVMPositionBuilderAtEnd(builder, mainBlock);

    LLVMValueRef args[1];
    auto constStr = LLVMConstString("punkso", 6, false);

    auto glob = LLVMAddGlobal(mod, LLVMTypeOf(constStr), "punkStr");
    LLVMSetInitializer(glob, constStr);
    LLVMSetGlobalConstant(glob, 1);
    LLVMSetLinkage(glob, LLVMLinkage.LLVMInternalLinkage);

    LLVMValueRef idx[2];
    idx[0] = LLVMConstInt(intTy, 0, false);
    idx[1] = LLVMConstInt(intTy, 0, false);
    args[0] = LLVMBuildGEP(
        builder,
        glob,
        idx.ptr,
        idx.length,
        "");

    LLVMBuildCall(builder, putsFun, args.ptr, args.length, "");

    LLVMBuildRet(builder, LLVMConstInt(intTy, 0, false));

    LLVMDumpModule(mod);

    return 0;
}
