import bustin.capi;

int main() {
    // needs more substance!
    auto ctxt = LLVMGetGlobalContext();
    auto builder = LLVMCreateBuilderInContext(ctxt);

    auto mod = LLVMModuleCreateWithNameInContext("test1", ctxt);

    auto voidTy = LLVMVoidTypeInContext(ctxt);

    auto intTy = LLVMInt32TypeInContext(ctxt);
    auto funTy = LLVMFunctionType(voidTy, null, 0, false);

    auto privFun = LLVMAddFunction(mod, "priv", funTy);
    LLVMSetLinkage(privFun, LLVMLinkage.LLVMPrivateLinkage);

    auto pumpFun = LLVMAddFunction(mod, "pump", funTy);

    auto block = LLVMAppendBasicBlock(pumpFun, "entry");

    LLVMPositionBuilderAtEnd(builder, block);

    LLVMBuildAlloca(builder, intTy, "fruitbat");

    auto v1 = LLVMConstInt(intTy, 14, false);
    auto ret1 = LLVMBuildFAdd(builder, v1, v1, "addit");
    auto ret2 = LLVMBuildFAdd(builder, ret1, v1, "addit");
    LLVMBuildRet(builder, ret2); // todo: return void instead and store above

    LLVMDumpModule(mod);

    return 0;
}
