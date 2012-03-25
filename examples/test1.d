import bustin.capi.core;
import bustin.core;

int main() {
    auto ctxt = getGlobalContext;
    auto builder = ctxt.createBuilder;
    auto mod = new Module("test1", ctxt);

    auto voidTy = ctxt.voidType;
    auto intTy = ctxt.int32Type;

    ////////////////////////////////////////////////////////////////////////
    // reference to external puts function from c library
    LLVMTypeRef[1] putsTypes;
    putsTypes[0] = ctxt.int8Type.pointerType(0).c;

    auto putsFun = mod.addFunction("puts", voidTy.functionType(putsTypes));

    ////////////////////////////////////////////////////////////////////////
    // pump function
    LLVMTypeRef[1] pumpTypes;
    pumpTypes[0] = intTy.c;

    auto pumpFun = mod.addFunction("pump", voidTy.functionType(pumpTypes));
    auto pumpBlock = pumpFun.appendBasicBlock;
    builder.positionBuilderAtEnd(pumpBlock);
    auto v1stack = builder.alloca(intTy, "fruitbat");
    auto v1 = intTy.const_(14);
    auto ret1 = builder.add(pumpFun.getParam(0), v1);
    auto ret2 = builder.add(ret1, v1);
    builder.store(ret2, v1stack);
    builder.retVoid;

    auto mainFun = mod.addFunction("main", intTy.functionType(null));
    auto mainBlock = mainFun.appendBasicBlock;
    builder.positionBuilderAtEnd(mainBlock);

    auto constStr = ctxt.constString("punkso");

    auto glob = mod.addGlobal(constStr.typeOf, "punkStr");
    glob.setInitializer(constStr);
    glob.setConstant(true);
    glob.setLinkage(LLVMLinkage.Internal);

    LLVMValueRef idx[2];
    idx[0] = LLVMConstInt(intTy.c, 0);
    idx[1] = LLVMConstInt(intTy.c, 0);

    LLVMValueRef args[1];
    args[0] = builder.GEP(glob, idx).c;

    builder.call(putsFun, args, "");
    builder.ret(intTy.const_(0));

    mod.dump();

    return 0;
}
