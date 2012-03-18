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
    extern struct LLVMOpaqueBasicBlock;

    alias LLVMOpaqueContext    *LLVMContextRef;
    alias LLVMOpaqueModule     *LLVMModuleRef;
    alias LLVMOpaqueBuilder    *LLVMBuilderRef;
    alias LLVMOpaqueValue      *LLVMValueRef;
    alias LLVMOpaqueType       *LLVMTypeRef;
    alias LLVMOpaqueBasicBlock *LLVMBasicBlockRef;

    alias int LLVMBool;

    //////////////////////////////////////////////////////////////////////////
    // external enums
    enum LLVMAttribute {
        LLVMZExtAttribute       = 1<<0,
        LLVMSExtAttribute       = 1<<1,
        LLVMNoReturnAttribute   = 1<<2,
        LLVMInRegAttribute      = 1<<3,
        LLVMStructRetAttribute  = 1<<4,
        LLVMNoUnwindAttribute   = 1<<5,
        LLVMNoAliasAttribute    = 1<<6,
        LLVMByValAttribute      = 1<<7,
        LLVMNestAttribute       = 1<<8,
        LLVMReadNoneAttribute   = 1<<9,
        LLVMReadOnlyAttribute   = 1<<10,
        LLVMNoInlineAttribute   = 1<<11,
        LLVMAlwaysInlineAttribute    = 1<<12,
        LLVMOptimizeForSizeAttribute = 1<<13,
        LLVMStackProtectAttribute    = 1<<14,
        LLVMStackProtectReqAttribute = 1<<15,
        LLVMAlignment = 31<<16,
        LLVMNoCaptureAttribute  = 1<<21,
        LLVMNoRedZoneAttribute  = 1<<22,
        LLVMNoImplicitFloatAttribute = 1<<23,
        LLVMNakedAttribute      = 1<<24,
        LLVMInlineHintAttribute = 1<<25,
        LLVMStackAlignment = 7<<26,
        LLVMReturnsTwice = 1 << 29,
        LLVMUWTable = 1 << 30,
        LLVMNonLazyBind = 1 << 31
    }

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
    }

    enum LLVMOpcode {
      /* Terminator Instructions */
      LLVMRet            = 1,
      LLVMBr             = 2,
      LLVMSwitch         = 3,
      LLVMIndirectBr     = 4,
      LLVMInvoke         = 5,
      /* removed 6 due to API changes */
      LLVMUnreachable    = 7,

      /* Standard Binary Operators */
      LLVMAdd            = 8,
      LLVMFAdd           = 9,
      LLVMSub            = 10,
      LLVMFSub           = 11,
      LLVMMul            = 12,
      LLVMFMul           = 13,
      LLVMUDiv           = 14,
      LLVMSDiv           = 15,
      LLVMFDiv           = 16,
      LLVMURem           = 17,
      LLVMSRem           = 18,
      LLVMFRem           = 19,

      /* Logical Operators */
      LLVMShl            = 20,
      LLVMLShr           = 21,
      LLVMAShr           = 22,
      LLVMAnd            = 23,
      LLVMOr             = 24,
      LLVMXor            = 25,

      /* Memory Operators */
      LLVMAlloca         = 26,
      LLVMLoad           = 27,
      LLVMStore          = 28,
      LLVMGetElementPtr  = 29,

      /* Cast Operators */
      LLVMTrunc          = 30,
      LLVMZExt           = 31,
      LLVMSExt           = 32,
      LLVMFPToUI         = 33,
      LLVMFPToSI         = 34,
      LLVMUIToFP         = 35,
      LLVMSIToFP         = 36,
      LLVMFPTrunc        = 37,
      LLVMFPExt          = 38,
      LLVMPtrToInt       = 39,
      LLVMIntToPtr       = 40,
      LLVMBitCast        = 41,

      /* Other Operators */
      LLVMICmp           = 42,
      LLVMFCmp           = 43,
      LLVMPHI            = 44,
      LLVMCall           = 45,
      LLVMSelect         = 46,
      LLVMUserOp1        = 47,
      LLVMUserOp2        = 48,
      LLVMVAArg          = 49,
      LLVMExtractElement = 50,
      LLVMInsertElement  = 51,
      LLVMShuffleVector  = 52,
      LLVMExtractValue   = 53,
      LLVMInsertValue    = 54,

      /* Atomic operators */
      LLVMFence          = 55,
      LLVMAtomicCmpXchg  = 56,
      LLVMAtomicRMW      = 57,

      /* Exception Handling Operators */
      LLVMResume         = 58,
      LLVMLandingPad     = 59,
      LLVMUnwind         = 60
    }

    //////////////////////////////////////////////////////////////////////////
    // context
    LLVMContextRef LLVMContextCreate();
    LLVMContextRef LLVMGetGlobalContext();

    //////////////////////////////////////////////////////////////////////////
    // builder
    LLVMBuilderRef LLVMCreateBuilderInContext(LLVMContextRef C);
    LLVMBuilderRef LLVMCreateBuilder();

    void LLVMPositionBuilder(LLVMBuilderRef Builder,
                             LLVMBasicBlockRef Block,
                             LLVMValueRef Instr);
    void LLVMPositionBuilderBefore(LLVMBuilderRef Builder,
                                   LLVMValueRef   Instr);
    void LLVMPositionBuilderAtEnd(LLVMBuilderRef Builder,
                                  LLVMBasicBlockRef Block);
    LLVMBasicBlockRef LLVMGetInsertBlock(LLVMBuilderRef Builder);
    void LLVMClearInsertionPosition(LLVMBuilderRef Builder);
    void LLVMInsertIntoBuilder(LLVMBuilderRef Builder, LLVMValueRef Instr);
    void LLVMInsertIntoBuilderWithName(LLVMBuilderRef Builder,
                                       LLVMValueRef Instr,
                                       const char *Name);
    void LLVMDisposeBuilder(LLVMBuilderRef Builder);

    // Terminators
    LLVMValueRef LLVMBuildRetVoid(LLVMBuilderRef);
    LLVMValueRef LLVMBuildRet(LLVMBuilderRef, LLVMValueRef V);

    /* Arithmetic */
    LLVMValueRef LLVMBuildAdd(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS,
                              const char *Name);
    LLVMValueRef LLVMBuildNSWAdd(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS,
                                 const char *Name);
    LLVMValueRef LLVMBuildNUWAdd(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS,
                                 const char *Name);
    LLVMValueRef LLVMBuildFAdd(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS,
                               const char *Name);
    LLVMValueRef LLVMBuildSub(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS,
                              const char *Name);
    LLVMValueRef LLVMBuildNSWSub(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS,
                                 const char *Name);
    LLVMValueRef LLVMBuildNUWSub(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS,
                                 const char *Name);
    LLVMValueRef LLVMBuildFSub(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS,
                               const char *Name);
    LLVMValueRef LLVMBuildMul(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS,
                              const char *Name);
    LLVMValueRef LLVMBuildNSWMul(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS,
                                 const char *Name);
    LLVMValueRef LLVMBuildNUWMul(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS,
                                 const char *Name);
    LLVMValueRef LLVMBuildFMul(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS,
                               const char *Name);
    LLVMValueRef LLVMBuildUDiv(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS,
                               const char *Name);
    LLVMValueRef LLVMBuildSDiv(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS,
                               const char *Name);
    LLVMValueRef LLVMBuildExactSDiv(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS,
                                    const char *Name);
    LLVMValueRef LLVMBuildFDiv(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS,
                               const char *Name);
    LLVMValueRef LLVMBuildURem(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS,
                               const char *Name);
    LLVMValueRef LLVMBuildSRem(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS,
                               const char *Name);
    LLVMValueRef LLVMBuildFRem(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS,
                               const char *Name);
    LLVMValueRef LLVMBuildShl(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS,
                               const char *Name);
    LLVMValueRef LLVMBuildLShr(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS,
                               const char *Name);
    LLVMValueRef LLVMBuildAShr(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS,
                               const char *Name);
    LLVMValueRef LLVMBuildAnd(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS,
                              const char *Name);
    LLVMValueRef LLVMBuildOr(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS,
                              const char *Name);
    LLVMValueRef LLVMBuildXor(LLVMBuilderRef, LLVMValueRef LHS, LLVMValueRef RHS,
                              const char *Name);
    LLVMValueRef LLVMBuildBinOp(LLVMBuilderRef B, LLVMOpcode Op,
                                LLVMValueRef LHS, LLVMValueRef RHS,
                                const char *Name);
    LLVMValueRef LLVMBuildNeg(LLVMBuilderRef, LLVMValueRef V, const char *Name);
    LLVMValueRef LLVMBuildNSWNeg(LLVMBuilderRef B, LLVMValueRef V,
                                 const char *Name);
    LLVMValueRef LLVMBuildNUWNeg(LLVMBuilderRef B, LLVMValueRef V,
                                 const char *Name);
    LLVMValueRef LLVMBuildFNeg(LLVMBuilderRef, LLVMValueRef V, const char *Name);
    LLVMValueRef LLVMBuildNot(LLVMBuilderRef, LLVMValueRef V, const char *Name);

    // memory
    LLVMValueRef LLVMBuildMalloc(LLVMBuilderRef, LLVMTypeRef Ty, const char *Name);
    LLVMValueRef LLVMBuildArrayMalloc(LLVMBuilderRef, LLVMTypeRef Ty,
                                      LLVMValueRef Val, const char *Name);
    LLVMValueRef LLVMBuildAlloca(LLVMBuilderRef, LLVMTypeRef Ty, const char *Name);
    LLVMValueRef LLVMBuildArrayAlloca(LLVMBuilderRef, LLVMTypeRef Ty,
                                      LLVMValueRef Val, const char *Name);
    LLVMValueRef LLVMBuildFree(LLVMBuilderRef, LLVMValueRef PointerVal);
    LLVMValueRef LLVMBuildLoad(LLVMBuilderRef, LLVMValueRef PointerVal,
                               const char *Name);
    LLVMValueRef LLVMBuildStore(LLVMBuilderRef, LLVMValueRef Val, LLVMValueRef Ptr);
    LLVMValueRef LLVMBuildGEP(LLVMBuilderRef B, LLVMValueRef Pointer,
                              LLVMValueRef *Indices, uint NumIndices,
                              const char *Name);
    LLVMValueRef LLVMBuildInBoundsGEP(LLVMBuilderRef B, LLVMValueRef Pointer,
                                      LLVMValueRef *Indices, uint NumIndices,
                                      const char *Name);
    LLVMValueRef LLVMBuildStructGEP(LLVMBuilderRef B, LLVMValueRef Pointer,
                                    uint Idx, const char *Name);
    LLVMValueRef LLVMBuildGlobalString(LLVMBuilderRef B, const char *Str,
                                       const char *Name);
    LLVMValueRef LLVMBuildGlobalStringPtr(LLVMBuilderRef B, const char *Str,
                                          const char *Name);

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
    // operations on parameters
    uint LLVMCountParams(LLVMValueRef Fn);
    void LLVMGetParams(LLVMValueRef Fn, LLVMValueRef *Params);
    LLVMValueRef LLVMGetParam(LLVMValueRef Fn, uint Index);
    LLVMValueRef LLVMGetParamParent(LLVMValueRef Inst);
    LLVMValueRef LLVMGetFirstParam(LLVMValueRef Fn);
    LLVMValueRef LLVMGetLastParam(LLVMValueRef Fn);
    LLVMValueRef LLVMGetNextParam(LLVMValueRef Arg);
    LLVMValueRef LLVMGetPreviousParam(LLVMValueRef Arg);
    void LLVMAddAttribute(LLVMValueRef Arg, LLVMAttribute PA);
    void LLVMRemoveAttribute(LLVMValueRef Arg, LLVMAttribute PA);
    LLVMAttribute LLVMGetAttribute(LLVMValueRef Arg);
    void LLVMSetParamAlignment(LLVMValueRef Arg, uint algn);

    //////////////////////////////////////////////////////////////////////////
    // operations on basic blocks
    LLVMBasicBlockRef LLVMAppendBasicBlock(LLVMValueRef Fn, const char *Name);

    // TODO: loads
}
