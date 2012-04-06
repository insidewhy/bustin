module bustin.execution_engine;

import bustin.gen.capi.execution_engine;
import bustin.gen.execution_engine;
import bustin.gen.capi.core;
import bustin.target;
import bustin.core;

class GenericValue {
    mixin GenericValueMixin;
}

class ExecutionEngine {
    mixin ExecutionEngineMixin;
}
