module bustin.capi;

// d .. uint = unsigned
//      ulong = unsigned long long

extern (C) {
    //////////////////////////////////////////////////////////////////////////
    // external types
    extern struct LLVMOpaqueContext;
    extern struct LLVMOpaqueModule;
    extern struct LLVMOpaqueBuilder;
    extern struct LLVMOpaqueValue;
    extern struct LLVMOpaqueType;

    alias LLVMOpaqueContext  *LLVMContextRef;
    alias LLVMOpaqueModule   *LLVMModuleRef;
    alias LLVMOpaqueBuilder  *LLVMBuilderRef;
    alias LLVMOpaqueValue    *LLVMValueRef;
    alias LLVMOpaqueType     *LLVMTypeRef;

    alias int LLVMBool;

    //////////////////////////////////////////////////////////////////////////
    // external enums
    enum LLVMLinkage {
      LLVMExternalLinkage,
      LLVMAvailableExternallyLinkage,
      LLVMLinkOnceAnyLinkage,
      LLVMLinkOnceODRLinkage,
      LLVMWeakAnyLinkage,
      LLVMWeakODRLinkage,
      LLVMAppendingLinkage,
      LLVMInternalLinkage,
      LLVMPrivateLinkage,
      LLVMDLLImportLinkage,
      LLVMDLLExportLinkage,
      LLVMExternalWeakLinkage,
      LLVMGhostLinkage,
      LLVMCommonLinkage,
      LLVMLinkerPrivateLinkage,
      LLVMLinkerPrivateWeakLinkage,
      LLVMLinkerPrivateWeakDefAutoLinkage
    };

    //////////////////////////////////////////////////////////////////////////
    // contexts
    LLVMContextRef LLVMContextCreate();
    LLVMContextRef LLVMGetGlobalContext();

    //////////////////////////////////////////////////////////////////////////
    // builders
    LLVMBuilderRef LLVMCreateBuilderInContext(LLVMContextRef C);
    LLVMBuilderRef LLVMCreateBuilder();

    //////////////////////////////////////////////////////////////////////////
    // modules
    LLVMModuleRef LLVMModuleCreateWithName(const char *ModuleID);
    LLVMModuleRef LLVMModuleCreateWithNameInContext(const char    *ModuleID,
                                                    LLVMContextRef C);
    void LLVMDumpModule(LLVMModuleRef M);

    //////////////////////////////////////////////////////////////////////////
    // types
    LLVMValueRef LLVMConstInt(LLVMTypeRef IntTy,
                              ulong       N, // unsigned long long in C..
                              LLVMBool    SignExtend);

    LLVMTypeRef LLVMInt1TypeInContext(LLVMContextRef C);
    LLVMTypeRef LLVMInt8TypeInContext(LLVMContextRef C);
    LLVMTypeRef LLVMInt16TypeInContext(LLVMContextRef C);
    LLVMTypeRef LLVMInt32TypeInContext(LLVMContextRef C);
    LLVMTypeRef LLVMInt64TypeInContext(LLVMContextRef C);
    LLVMTypeRef LLVMIntTypeInContext(LLVMContextRef C, uint NumBits);

    LLVMTypeRef LLVMInt1Type();
    LLVMTypeRef LLVMInt8Type();
    LLVMTypeRef LLVMInt16Type();
    LLVMTypeRef LLVMInt32Type();
    LLVMTypeRef LLVMInt64Type();
    LLVMTypeRef LLVMIntType(uint NumBits);
    uint LLVMGetIntTypeWidth(LLVMTypeRef IntegerTy);

    LLVMTypeRef LLVMVoidTypeInContext(LLVMContextRef C);
    LLVMTypeRef LLVMVoidType();

    //////////////////////////////////////////////////////////////////////////
    // functions
    LLVMTypeRef LLVMFunctionType(LLVMTypeRef ReturnType,
                                 LLVMTypeRef *ParamTypes, uint ParamCount,
                                 LLVMBool IsVarArg);

    LLVMBool LLVMIsFunctionVarArg(LLVMTypeRef FunctionTy);
    LLVMTypeRef LLVMGetReturnType(LLVMTypeRef FunctionTy);
    uint LLVMCountParamTypes(LLVMTypeRef FunctionTy);
    void LLVMGetParamTypes(LLVMTypeRef FunctionTy, LLVMTypeRef *Dest);

    //////////////////////////////////////////////////////////////////////////
    // operations on functions
    LLVMValueRef LLVMAddFunction(LLVMModuleRef M,
                                 const char   *Name,
                                 LLVMTypeRef   FunctionTy);

    LLVMValueRef LLVMGetNamedFunction(LLVMModuleRef M, const char *Name);
    LLVMValueRef LLVMGetFirstFunction(LLVMModuleRef M);
    LLVMValueRef LLVMGetLastFunction(LLVMModuleRef M);
    LLVMValueRef LLVMGetNextFunction(LLVMValueRef Fn);
    LLVMValueRef LLVMGetPreviousFunction(LLVMValueRef Fn);

    LLVMLinkage LLVMGetLinkage(LLVMValueRef Global);
    void LLVMSetLinkage(LLVMValueRef Global, LLVMLinkage Linkage);

    //////////////////////////////////////////////////////////////////////////
    // maths
    LLVMValueRef LLVMBuildFAdd(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS,
                               const char *Name);
    // TODO: loads
}
