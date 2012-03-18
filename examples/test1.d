import bustin.capi;

int main() {
    // needs more substance!
    auto ctxt = LLVMGetGlobalContext();
    auto builder = LLVMCreateBuilderInContext(ctxt);

    auto mod = LLVMModuleCreateWithNameInContext("test1", ctxt);

    auto voidTy = LLVMVoidTypeInContext(ctxt);
    auto funTy = LLVMFunctionType(voidTy, null, 0, false);

    auto privFun = LLVMAddFunction(mod, "priv", funTy);
    LLVMSetLinkage(privFun, LLVMLinkage.LLVMPrivateLinkage);

    // todo: from builder
    auto pumpFun = LLVMAddFunction(mod, "pump", funTy);
    auto v1 = LLVMConstInt(LLVMInt32TypeInContext(ctxt), 14, false);
    LLVMBuildFAdd(builder, v1, v1, "addit");


    LLVMDumpModule(mod);

    return 0;
}
