import bustin.capi.core;
import bustin.core;

int main() {
    auto ctxt = getGlobalContext;
    auto builder = ctxt.createBuilder;
    auto mod = new Module("test1", ctxt);

    auto intTy = ctxt.int32Type;

    ////////////////////////////////////////////////////////////////////////
    // reference to external puts function from c library
    LLVMTypeRef[1] putsTypes;
    putsTypes[0] = ctxt.int8Type.pointerType(0).c;

    auto putsFun = mod.addFunction(
        "puts", FunctionType.get(ctxt.voidType, putsTypes));

    ////////////////////////////////////////////////////////////////////////
    // pump function
    LLVMTypeRef[1] pumpTypes;
    pumpTypes[0] = intTy.c;

    auto pumpFun = mod.addFunction(
        "pump", FunctionType.get(ctxt.voidType, pumpTypes));
    builder.positionAtEnd(pumpFun.appendBasicBlock);
    auto v1 = intTy.const_(14);
    builder.store(builder.add(builder.add(pumpFun.getParam(0), v1), v1),
                  builder.alloca(intTy, "fruitbat"));
    builder.retVoid;

    builder.positionAtEnd(mod.addFunction(
        "main", FunctionType.get(intTy, null)).appendBasicBlock);

    auto constStr = ctxt.constString("punkso");
    auto glob = mod.addGlobal(constStr.typeOf, "punkStr");
    glob.setInitializer(constStr);
    glob.setConstant(true);
    glob.setLinkage(Linkage.Internal);

    LLVMValueRef idx[2];
    idx[0] = intTy.const_(0).c;
    idx[1] = intTy.const_(0).c;

    LLVMValueRef args[1];
    args[0] = builder.GEP(glob, idx).c;

    builder.call(putsFun, args);
    builder.ret(intTy.const_(0));

    mod.dump();

    return 0;
}
