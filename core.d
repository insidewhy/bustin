module bustin.core;

import bustin.gen.capi.core;
import bustin.gen.core;

alias LLVMLinkage            Linkage;
alias LLVMTypeKind           TypeKind;
alias LLVMVisibility         Visibility;
alias LLVMCallConv           CallConv;
alias LLVMIntPredicate       IntPredicate;
alias LLVMRealPredicate      RealPredicate;
alias LLVMLandingPadClauseTy LandingPadClauseTy;
alias LLVMAttribute          Attribute;
alias LLVMOpcode             Opcode;

class Value {
    mixin ValueMixin;
}

class User : Value {
    mixin UserMixin;
}

class Constant : User {
    mixin ConstantMixin;
}

class Type {
    mixin TypeMixin;
}

class StructType : Type {
    mixin StructTypeMixin;
}

class IntegerType : Type {
    mixin IntegerTypeMixin;
}

class RealType : Type {
    mixin RealTypeMixin;
}

class FunctionType : Type {
    mixin FunctionTypeMixin;

    static auto get(Type ret, LLVMTypeRef[] param, bool isVarArg = false) {
        return new FunctionType(LLVMFunctionType(
            ret.c, param.ptr, cast(uint)param.length, isVarArg));
    }
}

class Use {
    mixin UseMixin;
}

class BasicBlock : Value {
    alias LLVMBasicBlockRef CType;
    CType c;
    mixin BasicBlockMixin;

    this(CType c_ = null) {
        c = c_;
        super(LLVMBasicBlockAsValue(c));
    };
}

class GlobalVariable : GlobalValue {
    mixin GlobalVariableMixin;
}

class GlobalValue : Constant {
    mixin GlobalValueMixin;
}

class Function : GlobalValue {
    mixin FunctionMixin;
}

class Instruction : User {
    mixin InstructionMixin;
}

class CallInst : Instruction {
    mixin CallInstMixin;
}

class Context {
    mixin ContextMixin;
}

Context getGlobalContext() { return new Context(LLVMGetGlobalContext()); }

class Builder {
    mixin BuilderMixin;

    // c++ uses this
    auto createRet(Value v) { return ret(v); }
}

class Module {
    mixin ModuleMixin;

    this(const char *ModuleID, Context C) {
        c = LLVMModuleCreateWithNameInContext(ModuleID, C.c);
    }

    this(CType c_ = null) { c = c_; }; // it's in the mixin too but alas..
}

class PassManager {
    mixin PassManagerMixin;

    this(Module m) {
        c = LLVMCreateFunctionPassManagerForModule(m.c);
    }

    this(CType c_ = null) { c = c_; }; // it's in the mixin too but alas..
}
