// jpike: found this file at http://pastebin.com/Skgrvajg, makes a nice
//        reference to the c api
module tests.Examples;

import tango.io.Stdout;


import llvmbe.Utils;
import llvmbe.Builder;
import llvmbe.Runner;

void dump(LLVMValueRef v){ LLVMDumpValue(v); }
void dump(LLVMModuleRef v) { LLVMDumpModule(v); }
void dump(LLVMTypeRef v) { LLVMDumpType(v); }


/*
unsigned gcd(unsigned x, unsigned y) {
  if(x == y) {
    return x;
  } else if(x < y) {
    return gcd(x, y - x);
  } else {
    return gcd(x - y, y);
  }
}
*/
/*
; ModuleID = 'Test1'

define i32 @gcd(i32 %x, i32 %y) {
entry:
  %tmp = icmp eq i32 %x, %y                       ; <i1> [#uses=1]
  br i1 %tmp, label %return, label %next

return:                                           ; preds = %entry
  ret i32 %x

next:                                             ; preds = %entry
  %tmp1 = icmp ult i32 %x, %y                     ; <i1> [#uses=1]
  br i1 %tmp1, label %cond_true, label %cond_false

cond_true:                                        ; preds = %next
  %tmp2 = sub i32 %y, %x                          ; <i32> [#uses=1]
  %tmp3 = call i32 @gcd(i32 %x, i32 %tmp2)        ; <i32> [#uses=1]
  ret i32 %tmp3

cond_false:                                       ; preds = %next
  %tmp4 = sub i32 %x, %y                          ; <i32> [#uses=1]
  %tmp5 = call i32 @gcd(i32 %tmp4, i32 %y)        ; <i32> [#uses=1]
  ret i32 %tmp5
}
*/
//http://llvm.org/docs/tutorial/JITTutorial2.html
LLVMModuleRef createTestModule1()
{
    LLVMModuleRef mod = createModule("Test1");

    auto param_types = [LLVMInt32Type(), LLVMInt32Type()];
    auto ret_type = LLVMInt32Type();
    auto func_type = LLVMFunctionType(ret_type, param_types.ptr, param_types.length, 0);
    auto gcd = LLVMAddFunction(mod, "gcd", func_type);

    auto b = LLVMCreateBuilder();
    //scope(exit) LLVMDisposeBuilder(b);

    auto x = LLVMGetParam(gcd, 0);
    auto y = LLVMGetParam(gcd, 1);
    LLVMSetValueName(x, "x");
    LLVMSetValueName(y, "y");


    auto entry = LLVMAppendBasicBlock(gcd, "entry");
    auto ret = LLVMAppendBasicBlock(gcd, "return");
    auto next = LLVMAppendBasicBlock(gcd, "next");
    auto cond_true = LLVMAppendBasicBlock(gcd, "cond_true");
    auto cond_false = LLVMAppendBasicBlock(gcd, "cond_false");


    LLVMPositionBuilderAtEnd(b, entry);
    LLVMValueRef xEqualsY = LLVMBuildICmp(b, LLVMIntPredicate.EQ, x, y, "tmp");
    LLVMBuildCondBr(b, xEqualsY, ret, next);

    LLVMPositionBuilderAtEnd(b, ret);
    LLVMBuildRet(b, x);

    LLVMPositionBuilderAtEnd(b, next);
    LLVMValueRef xLessThanY = LLVMBuildICmp(b, LLVMIntPredicate.ULT, x, y, "tmp");
    LLVMBuildCondBr(b, xLessThanY, cond_true, cond_false);

    LLVMPositionBuilderAtEnd(b, cond_true);
    auto yMinusX = LLVMBuildSub(b, y, x, "tmp");
    auto args1 = [x, yMinusX];
    LLVMValueRef recur_1 = LLVMBuildCall(b, gcd, args1.ptr, args1.length, "tmp");
    LLVMBuildRet(b, recur_1);

    LLVMPositionBuilderAtEnd(b, cond_false);
    LLVMValueRef xMinusY = LLVMBuildSub(b, x, y, "tmp");
    auto args = [xMinusY, y];
    LLVMValueRef recur_2 = LLVMBuildCall(b, gcd, args.ptr, args.length, "tmp");
    LLVMBuildRet(b, recur_2);

    //LLVMBuildUnreachable(b)

    return mod;
}


/*
; ModuleID = 'Test2'

define i32 @gcd(i32 %x, i32 %y) {
entry:
  %.__alloca_point__. = alloca [0 x i1]           ; <[0 x i1]*> [#uses=0]
  %0 = icmp eq i32 %x, %y                         ; <i1> [#uses=1]
  br i1 %0, label %return, label %next

return:                                           ; preds = %entry
  ret i32 %x

next:                                             ; preds = %entry
  %1 = icmp ult i32 %x, %y                        ; <i1> [#uses=1]
  br i1 %1, label %cond_true, label %cond_false

cond_true:                                        ; preds = %next
  %2 = sub i32 %y, %x                             ; <i32> [#uses=1]
  %3 = call i32 @gcd(i32 %x, i32 %2)              ; <i32> [#uses=1]
  ret i32 %3

cond_false:                                       ; preds = %next
  %4 = sub i32 %x, %y                             ; <i32> [#uses=1]
  %5 = call i32 @gcd(i32 %4, i32 %y)              ; <i32> [#uses=1]
  ret i32 %5

end_entry:                                        ; No predecessors!
  unreachable
}
*/
LLVMModuleRef createTestModule2()
{
    LLVMModuleRef mod = createModule("Test2");

    auto param_types = [LLVMInt32Type(), LLVMInt32Type()];
    auto ret_type = LLVMInt32Type();
    auto func_type = LLVMFunctionType(ret_type, param_types.ptr, param_types.length, 0);
    auto gcd = LLVMAddFunction(mod, "gcd", func_type);

    auto x = LLVMGetParam(gcd, 0);
    auto y = LLVMGetParam(gcd, 1);
    LLVMSetValueName(x, "x");
    LLVMSetValueName(y, "y");

    auto b = new Builder(null, gcd);
    //scope(exit) b.free();

    //#########


    auto entry = b.backBlock; //b is end

    //insert into current block
    auto ret = b.addBlock("return");
    auto next = b.addBlock("next");
    auto cond_true = b.addBlock("cond_true");
    auto cond_false = b.addBlock("cond_false");

    auto c1 = b.icmp(LLVMIntPredicate.EQ, x, y);
    b.br(c1, ret, next);

    b.pushScope(ret, next); //b is set to ret
    b.ret(x);
    b.popScope(next); //b is set to next

    auto c2 = b.icmp(LLVMIntPredicate.ULT, x, y);
    b.br(c2, cond_true, cond_false);

    b.pushScope(cond_true, cond_false); //b is set cond_true

    auto yMinusX = b.sub(y, x);
    auto args1 = [x, yMinusX];
    LLVMValueRef tmp1 = b.call(gcd, args1);
    b.ret(tmp1);

    b.setScope(cond_false, entry); //b is set cond_false

    auto xMinusY = b.sub(x, y);
    auto args2 = [xMinusY, y];
    LLVMValueRef tmp2 = b.call(gcd, args2);
    b.ret(tmp2);

    b.popScope(entry); //b is set end


    //#########

    b.unreachable();

    return mod;
}

/*
int main()
{
  printf("Hello World!\n");
}
*/
LLVMModuleRef createTestModule3()
{
    // create module
    LLVMModuleRef mod = createModule("Test3");
    //scope(exit) LLVMDisposeModule(mod);

    // declare string
    char[] str = "Hello World!\n";
    auto chello = LLVMConstString(str.ptr, str.length, false);
    auto hello_value = LLVMAddGlobal(mod, LLVMTypeOf(chello), toStringz("str"));
    LLVMSetInitializer(hello_value, chello);
    LLVMSetGlobalConstant(hello_value, 1);
    LLVMSetLinkage(hello_value, LLVMLinkage.Internal);
//dump(hello_value); //@str = internal constant [14 x i8] c"Hello World!\0A\00" ; <[14 x i8]*> [#uses=0]

    // declare printf
    auto printf_param_types = [LLVMPointerType(LLVMInt8Type(), 0)];
    auto printf_ret_type = LLVMInt32Type();
    auto printf_type = LLVMFunctionType(printf_ret_type, printf_param_types.ptr, printf_param_types.length, 1 /*is vararg*/);
    auto llprintf = LLVMAddFunction(mod, "printf", printf_type);

    // declare main
    auto main_ret_type = LLVMInt32Type();
    auto main_type = LLVMFunctionType(main_ret_type, null, 0, 0);
    auto llmain = LLVMAddFunction(mod, "main", main_type);

    // create builder
    auto builder = LLVMCreateBuilder();
    scope(exit) LLVMDisposeBuilder(builder);

    // create main body block
    auto bb = LLVMAppendBasicBlock(llmain, toStringz("entry"));
    LLVMPositionBuilderAtEnd(builder, bb);

    // call printf
    auto zero = LLVMConstInt(LLVMInt32Type(), 0, false);
    LLVMValueRef[] llindices = [zero, zero];
    auto helloptr = LLVMBuildGEP(builder, hello_value, llindices.ptr, llindices.length, toStringz("str"));
    //LLVMDumpValue(helloptr);
    auto llargs = [helloptr];
    LLVMBuildCall(builder, llprintf, llargs.ptr, llargs.length, "result");

    // return 0
    LLVMBuildRet(builder, LLVMConstInt(LLVMInt32Type(), 0, true));

    return mod;
}

/*
int main()
{
  printf("Hello World!\n", 1 + 2 + 3);
}
*/
/*
; ModuleID = 'Test4'

@str = internal constant [17 x i8] c"Hello %d World!\0A\00" ; <[17 x i8]*> [#uses=1]

declare i32 @printf(i8*, ...)

define i32 @main() {
entry:
  %result = call i32 (i8*, ...)* @printf(i8* getelementptr ([17 x i8]* @str, i32 0, i32 0), i32 6) ; <i32> [#uses=0]
  ret i32 0
}
*/
LLVMModuleRef createTestModule4()
{
    // create module
    LLVMModuleRef mod = createModule("Test4");
    //scope(exit) LLVMDisposeModule(mod);

    // declare string
    char[] str = "Hello %d World!\n";
    auto chello = LLVMConstString(str.ptr, str.length, false);
    auto hello_value = LLVMAddGlobal(mod, LLVMTypeOf(chello), toStringz("str"));
    LLVMSetInitializer(hello_value, chello);
    LLVMSetGlobalConstant(hello_value, 1);
    LLVMSetLinkage(hello_value, LLVMLinkage.Internal);
//dump(hello_value); //@str = internal constant [14 x i8] c"Hello World!\0A\00" ; <[14 x i8]*> [#uses=0]

    // declare printf
    auto printf_param_types = [LLVMPointerType(LLVMInt8Type(), 0)];
    auto printf_ret_type = LLVMInt32Type();
    auto printf_type = LLVMFunctionType(printf_ret_type, printf_param_types.ptr, printf_param_types.length, 1 /*is vararg*/);
    auto llprintf = LLVMAddFunction(mod, "printf", printf_type);

    // declare main
    auto main_ret_type = LLVMInt32Type();
    auto main_type = LLVMFunctionType(main_ret_type, null, 0, 0);
    auto llmain = LLVMAddFunction(mod, "main", main_type);

    // create builder
    auto builder = LLVMCreateBuilder();
    scope(exit) LLVMDisposeBuilder(builder);

    // create main body block
    auto bb = LLVMAppendBasicBlock(llmain, toStringz("entry"));
    LLVMPositionBuilderAtEnd(builder, bb);

    //1 + 2 + 3
    auto sum = LLVMConstInt(LLVMInt32Type(),1, 0);
    auto r1 = LLVMConstInt(LLVMInt32Type(), 2, 0);
    auto r2 = LLVMConstInt(LLVMInt32Type(), 3, 0);
    sum = LLVMBuildAdd(builder, sum, r1, "");
    sum = LLVMBuildAdd(builder, sum, r2, "");

    // call printf
    auto zero = LLVMConstInt(LLVMInt32Type(), 0, false);
    LLVMValueRef[] llindices = [zero, zero];
    auto helloptr = LLVMBuildGEP(builder, hello_value, llindices.ptr, llindices.length, toStringz("str"));
    //LLVMDumpValue(helloptr);
    auto llargs = [helloptr, sum];
    LLVMBuildCall(builder, llprintf, llargs.ptr, llargs.length, "result");

    // return 0
    LLVMBuildRet(builder, LLVMConstInt(LLVMInt32Type(), 0, true));

    return mod;
}

/*
int main()
{
  uint i = 0;
   i = i + 1;
  printf("Result %d!\n", i);
}
*/
/*
; ModuleID = 'Test5'

@str = internal constant [11 x i8] c"Result %d\0A\00" ; <[11 x i8]*> [#uses=1]

declare i32 @printf(i8*, ...)

define i32 @main() {
entry:
  %i = alloca i32                                 ; <i32*> [#uses=2]
  store i32 0, i32* %i
  %0 = load i32* %i                               ; <i32> [#uses=1]
  %1 = add i32 %0, 2                              ; <i32> [#uses=1]
  %result = call i32 (i8*, ...)* @printf(i8* getelementptr ([11 x i8]* @str, i32 0, i32 0), i32 %1) ; <i32> [#uses=0]
  ret i32 0
}
*/
LLVMModuleRef createTestModule5()
{
    // create module
    LLVMModuleRef mod = createModule("Test5");
    //scope(exit) LLVMDisposeModule(mod);

    // declare string
    char[] str = "Result %d\n";
    auto chello = LLVMConstString(str.ptr, str.length, false);
    auto hello_value = LLVMAddGlobal(mod, LLVMTypeOf(chello), toStringz("str"));
    LLVMSetInitializer(hello_value, chello);
    LLVMSetGlobalConstant(hello_value, 1);
    LLVMSetLinkage(hello_value, LLVMLinkage.Internal);


    // declare printf
    auto printf_param_types = [LLVMPointerType(LLVMInt8Type(), 0)];
    auto printf_ret_type = LLVMInt32Type();
    auto printf_type = LLVMFunctionType(printf_ret_type, printf_param_types.ptr, printf_param_types.length, 1);
    auto llprintf = LLVMAddFunction(mod, "printf", printf_type);

    // declare main
    auto main_ret_type = LLVMInt32Type();
    auto main_type = LLVMFunctionType(main_ret_type, null, 0, 0);
    auto llmain = LLVMAddFunction(mod, "main", main_type);

    // create builder
    auto builder = LLVMCreateBuilder();
    scope(exit) LLVMDisposeBuilder(builder);

    // create main body block
    auto bb = LLVMAppendBasicBlock(llmain, toStringz("entry"));
    LLVMPositionBuilderAtEnd(builder, bb);

    //uint i;
    auto mem = LLVMBuildAlloca(builder, LLVMInt32Type(), "i");
    // LLVMSetAllocaAlign(mem, vd.getAlignment);

    //i = 0;
    auto init = LLVMConstInt(LLVMInt32Type(),0, 0);
    /*auto val =*/ LLVMBuildStore(builder, init, mem);

    //i = i + 1;
    auto mem_val = LLVMBuildLoad(builder, mem, "");
    auto r1 = LLVMConstInt(LLVMInt32Type(), 42, 0);
    auto sum = LLVMBuildAdd(builder, mem_val, r1, "");

    // call printf
    auto zero = LLVMConstInt(LLVMInt32Type(), 0, false);
    LLVMValueRef[] llindices = [zero, zero];
    auto helloptr = LLVMBuildGEP(builder, hello_value, llindices.ptr, llindices.length, toStringz("str"));
    //LLVMDumpValue(helloptr);
    auto llargs = [helloptr, sum];
    LLVMBuildCall(builder, llprintf, llargs.ptr, llargs.length, "result");

    // return 0
    LLVMBuildRet(builder, LLVMConstInt(LLVMInt32Type(), 0, true));

    return mod;
}

/*
char* malloc(size_t size);

void main()
{
    struct Foo
    {
        uint i;
    };
    Foo* foo;
    foo = (Foo*) malloc(4);
}
*/
/*
; ModuleID = 'Test6'

%0 = type <{ i64 }>

declare i8* @malloc(i64)

define void @main() {
entry:
  %foo = alloca %0*                               ; <%0**> [#uses=1]
  %result = call i8* @malloc(i64 8)               ; <i8*> [#uses=1]
  %0 = bitcast i8* %result to %0*                 ; <%0*> [#uses=1]
  store %0* %0, %0** %foo
  ret void
}
*/
LLVMModuleRef createTestModule6()
{
    // create module
    LLVMModuleRef mod = createModule("Test6");
    //scope(exit) LLVMDisposeModule(mod);

    // declare malloc
    auto malloc_param_types = [LLVMInt64Type()];
    auto malloc_ret_type = LLVMPointerType(LLVMInt8Type(), 0);
    auto malloc_type = LLVMFunctionType(malloc_ret_type, malloc_param_types.ptr, malloc_param_types.length, 0);
    auto llmalloc = LLVMAddFunction(mod, "malloc", malloc_type);

    // declare main
    auto main_ret_type = LLVMVoidType();
    auto main_type = LLVMFunctionType(main_ret_type, null, 0, 0);
    auto llmain = LLVMAddFunction(mod, "main", main_type);

    // create builder
    auto builder = LLVMCreateBuilder();
    scope(exit) LLVMDisposeBuilder(builder);

    LLVMTypeRef[] types = [LLVMInt64Type()];
    auto llstruct = LLVMStructType(types.ptr, cast(uint) types.length, 1 /*packed*/);

    // create main body block
    auto bb = LLVMAppendBasicBlock(llmain, toStringz("entry"));
    LLVMPositionBuilderAtEnd(builder, bb);

    // Foo* foo;
    auto mem = LLVMBuildAlloca(builder, LLVMPointerType(llstruct, 0), "foo");

    // call malloc
    auto llargs = [LLVMConstInt(LLVMInt64Type(), 8, false)];
    auto result = LLVMBuildCall(builder, llmalloc, llargs.ptr, llargs.length, "result");

    result = LLVMBuildBitCast(builder, result, LLVMGetElementType(LLVMTypeOf(mem)), "");
    LLVMBuildStore(builder, result, mem);

    LLVMBuildRetVoid(builder);

    return mod;
}

/*
char* malloc(size_t size);

void main()
{
    uint* i;
    i = malloc(4);
    *i = 24;
}
*/
/*
; ModuleID = 'Test7'

declare i8* @malloc(i64)

define void @main() {
entry:
  %i = alloca i64*                                ; <i64**> [#uses=2]
  %result = call i8* @malloc(i64 8)               ; <i8*> [#uses=1]
  %0 = bitcast i8* %result to i64*                ; <i64*> [#uses=1]
  store i64* %0, i64** %i
  %1 = load i64** %i                              ; <i64*> [#uses=1]
  store i64 24, i64* %1
  ret void
}
*/
LLVMModuleRef createTestModule7()
{
    // create module
    LLVMModuleRef mod = createModule("Test7");
    //scope(exit) LLVMDisposeModule(mod);

    // declare malloc
    auto malloc_param_types = [LLVMInt64Type()];
    auto malloc_ret_type = LLVMPointerType(LLVMInt8Type(), 0);
    auto malloc_type = LLVMFunctionType(malloc_ret_type, malloc_param_types.ptr, malloc_param_types.length, 0);
    auto llmalloc = LLVMAddFunction(mod, "malloc", malloc_type);

    // declare main
    auto main_ret_type = LLVMVoidType();
    auto main_type = LLVMFunctionType(main_ret_type, null, 0, 0);
    auto llmain = LLVMAddFunction(mod, "main", main_type);

    // create builder
    auto builder = LLVMCreateBuilder();
    scope(exit) LLVMDisposeBuilder(builder);

    // create main body block
    auto bb = LLVMAppendBasicBlock(llmain, toStringz("entry"));
    LLVMPositionBuilderAtEnd(builder, bb);

    // uint* i;
    auto mem = LLVMBuildAlloca(builder, LLVMPointerType(LLVMInt64Type(), 0), "i");

    // call malloc
    auto llargs = [LLVMConstInt(LLVMInt64Type(), 8, false)];
    auto result = LLVMBuildCall(builder, llmalloc, llargs.ptr, llargs.length, "result");

    result = LLVMBuildBitCast(builder, result, LLVMGetElementType(LLVMTypeOf(mem)), "");
    LLVMBuildStore(builder, result, mem);

    // *i = 24;
    auto ptr_loc = LLVMBuildLoad(builder, mem, "");
    LLVMBuildStore(builder, LLVMConstInt(LLVMInt64Type(), 24, false), ptr_loc);

    LLVMBuildRetVoid(builder);

    return mod;
}

/*
http://npcontemplation.blogspot.com/2008/06/secret-of-llvm-c-bindings.html
int fac(uint n)
{
    if(n == 0)
    {
        return 1;
    }
    else
    {
        return n * fac(n - 1)
    }
}
*/
void createAndRunFacFunc()
{
    LLVMLinkInJIT();
    LLVMInitializeX86Target();
    LLVMInitializeX86TargetInfo();

    char* error = null;
    LLVMModuleRef mod = LLVMModuleCreateWithName("fac_module");
    LLVMTypeRef[] fac_args = [ LLVMInt32Type() ];
    LLVMValueRef fac = LLVMAddFunction(mod, "fac", LLVMFunctionType(LLVMInt32Type(), fac_args.ptr, 1, 0));
    LLVMSetFunctionCallConv(fac, LLVMCallConv.C);
    LLVMValueRef n = LLVMGetParam(fac, 0);

    LLVMBasicBlockRef entry = LLVMAppendBasicBlock(fac, "entry");
    LLVMBasicBlockRef iftrue = LLVMAppendBasicBlock(fac, "iftrue");
    LLVMBasicBlockRef iffalse = LLVMAppendBasicBlock(fac, "iffalse");
    LLVMBasicBlockRef end = LLVMAppendBasicBlock(fac, "end");
    LLVMBuilderRef builder = LLVMCreateBuilder();

    //if (n == 0)
    LLVMPositionBuilderAtEnd(builder, entry);
    LLVMValueRef If = LLVMBuildICmp(builder, LLVMIntPredicate.EQ, n, LLVMConstInt(LLVMInt32Type(), 0, 0), "n == 0");
    LLVMBuildCondBr(builder, If, iftrue, iffalse);

    //if true
    LLVMPositionBuilderAtEnd(builder, iftrue);
    LLVMValueRef res_iftrue = LLVMConstInt(LLVMInt32Type(), 1, 0);
    LLVMBuildBr(builder, end);

    //if false
    LLVMPositionBuilderAtEnd(builder, iffalse);
    LLVMValueRef n_minus = LLVMBuildSub(builder, n, LLVMConstInt(LLVMInt32Type(), 1, 0), "n - 1");
    LLVMValueRef[] call_fac_args = [n_minus];
    LLVMValueRef call_fac = LLVMBuildCall(builder, fac, call_fac_args.ptr, 1, "fac(n - 1)");
    LLVMValueRef res_iffalse = LLVMBuildMul(builder, n, call_fac, "n * fac(n - 1)");
    LLVMBuildBr(builder, end);

    LLVMPositionBuilderAtEnd(builder, end);
    LLVMValueRef res = LLVMBuildPhi(builder, LLVMInt32Type(), "result");
    LLVMValueRef[] phi_vals = [res_iftrue, res_iffalse];
    LLVMBasicBlockRef[] phi_blocks = [iftrue, iffalse];
    LLVMAddIncoming(res, phi_vals.ptr, phi_blocks.ptr, 2);
    LLVMBuildRet(builder, res);

    if(LLVMVerifyModule(mod, LLVMVerifierFailureAction.ReturnStatus, &error))
    {
        auto msg = fromStringz(error).dup;
        LLVMDisposeMessage(error);
        throw new Exception(msg);
    }

    LLVMExecutionEngineRef engine;
    LLVMModuleProviderRef provider = LLVMCreateModuleProviderForExistingModule(mod);
    error = null;

    if(LLVMCreateJITCompiler(&engine, provider, 2, &error))
    {
        auto msg = fromStringz(error).dup;
        LLVMDisposeMessage(error);
        throw new Exception(msg);
    }

    LLVMPassManagerRef pass = LLVMCreatePassManager();
    LLVMAddTargetData(LLVMGetExecutionEngineTargetData(engine), pass);
    LLVMAddConstantPropagationPass(pass);
    LLVMAddInstructionCombiningPass(pass);
    LLVMAddPromoteMemoryToRegisterPass(pass);
    // LLVMAddDemoteMemoryToRegisterPass(pass); //Demotes every possible value to memory
    LLVMAddGVNPass(pass);
    LLVMAddCFGSimplificationPass(pass);
    LLVMRunPassManager(pass, mod);
    //LLVMDumpModule(mod);

    LLVMGenericValueRef[] exec_args = [LLVMCreateGenericValueOfInt(LLVMInt32Type(), 10, 0)];
    LLVMGenericValueRef exec_res = LLVMRunFunction(engine, fac, 1, exec_args.ptr);
    Stdout("\n; Running fac(10)...\n");
    Stdout("; Result: ")(LLVMGenericValueToInt(exec_res, 0)).newline;

    //
    //LLVMFreeMachineCodeForFunction(executionengine, function);

    LLVMDisposePassManager(pass);
    LLVMDisposeBuilder(builder);
    LLVMDisposeExecutionEngine(engine);
}

/*
void foo(uint x)
{
    printf("%d", x);
}

void main()
{
  foo(42);
}
*/
void createCallExample()
{
    LLVMLinkInJIT();
    LLVMInitializeX86Target();
    LLVMInitializeX86TargetInfo();

    char* error = null;
    LLVMModuleRef mod = LLVMModuleCreateWithName("module");

    // declare string
    char[] str = "foo: %d\n";
    auto cstr = LLVMConstString(str.ptr, str.length, false);
    auto str_value = LLVMAddGlobal(mod, LLVMTypeOf(cstr), toStringz("str"));
    LLVMSetInitializer(str_value, cstr);
    LLVMSetGlobalConstant(str_value, 1);
    LLVMSetLinkage(str_value, LLVMLinkage.Internal);

    // declare printf
    auto printf_param_types = [LLVMPointerType(LLVMInt8Type(), 0)];
    auto printf_ret_type = LLVMInt32Type();
    auto printf_type = LLVMFunctionType(printf_ret_type, printf_param_types.ptr, printf_param_types.length, 1);
    auto printf = LLVMAddFunction(mod, "printf", printf_type);

    // declare foo
    auto foo_param_types = [LLVMInt32Type()].dup;
    auto foo_type = LLVMFunctionType(LLVMVoidType(), foo_param_types.ptr, foo_param_types.length, 0);
    auto foo = LLVMAddFunction(mod, "foo", foo_type);

    // create builder for foo
    auto foo_builder = LLVMCreateBuilder();
    scope(exit) LLVMDisposeBuilder(foo_builder);

    // create foo body block
    auto foo_bb = LLVMAppendBasicBlock(foo, toStringz("entry"));
    LLVMPositionBuilderAtEnd(foo_builder, foo_bb);

    // call printf
    LLVMValueRef[] llindices = [LLVMConstInt(LLVMInt32Type(), 0, false), LLVMConstInt(LLVMInt32Type(), 0, false)].dup;
    auto str_ptr = LLVMBuildGEP(foo_builder, str_value, llindices.ptr, llindices.length, toStringz("str"));
    auto printf_args = [str_ptr, LLVMGetParam(foo, 0)];
    LLVMBuildCall(foo_builder, printf, printf_args.ptr, printf_args.length, "");

    LLVMBuildRetVoid(foo_builder);

    // declare main
    auto main_type = LLVMFunctionType(LLVMVoidType(), null, 0, 0);
    auto main = LLVMAddFunction(mod, "main", main_type);

    // create builder for main
    auto main_builder = LLVMCreateBuilder();
    scope(exit) LLVMDisposeBuilder(main_builder);

    // create main body block
    auto main_bb = LLVMAppendBasicBlock(main, toStringz("entry"));
    LLVMPositionBuilderAtEnd(main_builder, main_bb);

    auto foo_args = [LLVMConstInt(LLVMInt32Type(), 42, false)];
    LLVMBuildCall(main_builder, foo, foo_args.ptr, foo_args.length, "");

    LLVMBuildRetVoid(main_builder);


    if(LLVMVerifyModule(mod, LLVMVerifierFailureAction.ReturnStatus, &error))
    {
        auto msg = fromStringz(error).dup;
        LLVMDisposeMessage(error);
        throw new Exception(msg);
    }

    LLVMExecutionEngineRef engine;
    LLVMModuleProviderRef provider = LLVMCreateModuleProviderForExistingModule(mod);
    error = null;

    if(LLVMCreateJITCompiler(&engine, provider, 2, &error))
    {
        auto msg = fromStringz(error).dup;
        LLVMDisposeMessage(error);
        throw new Exception(msg);
    }

    LLVMPassManagerRef pass = LLVMCreatePassManager();
    LLVMAddTargetData(LLVMGetExecutionEngineTargetData(engine), pass);
    LLVMAddConstantPropagationPass(pass);
    LLVMAddInstructionCombiningPass(pass);
    LLVMAddPromoteMemoryToRegisterPass(pass);
    // LLVMAddDemoteMemoryToRegisterPass(pass); //Demotes every possible value to memory
    LLVMAddGVNPass(pass);
    LLVMAddCFGSimplificationPass(pass);
    LLVMRunPassManager(pass, mod);

    LLVMDumpModule(mod);

    Stdout("Run main:").newline;
    LLVMRunFunction(engine, main, 0, null);
}
