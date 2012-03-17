module bustin.capi;

extern (C) {
    extern struct LLVMOpaqueContext;
    alias LLVMOpaqueContext *LLVMContextRef;
    LLVMContextRef LLVMContextCreate();
    LLVMContextRef LLVMGetGlobalContext();

    // TODO: loads
}
