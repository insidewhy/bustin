module bustin.core;
import bustin.gen.core;
import bustin.gen.core_obj;

class Context {
    mixin ContextMixin;
}

Context getGlobalContext() { return new Context(LLVMGetGlobalContext()); }

class Type {
    mixin TypeMixin;
}

class StructType : Type {
    mixin StructTypeMixin;
}

class Builder {
    mixin BuilderMixin;
}

class Value {
    mixin ValueMixin;
}

class User : Value {
    mixin UserMixin;
}

class PassManager {
    mixin PassManagerMixin;
}

class Constant : User {
    mixin ConstantMixin;
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

class FunctionType : Type {
    mixin FunctionTypeMixin;
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

class IntegerType : Type {
    mixin IntegerTypeMixin;
}

class Module {
    mixin ModuleMixin;

    this(const char *ModuleID, Context C) {
        c = LLVMModuleCreateWithNameInContext(ModuleID, C.c);
    }

    this(CType c_ = null) { c = c_; }; // it's in the mixin too but alas..
}

class GlobalVariable : GlobalValue {
    mixin GlobalVariableMixin;
}

class RealType : Type {
    mixin RealTypeMixin;
}

alias LLVMLinkage Linkage;
