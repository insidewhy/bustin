#!/usr/bin/env perl

# hacky perl script, the llvm authors are pretty consistent with their
# formatting so this doesn't have to be perfect

use strict;
use File::Path qw(make_path);

my $basedir = '/usr/include/llvm-c/';
my $outdir = './gen/';

sub subout($) {
    my $out = shift;
    return sub($) {
        my $name = shift;
        $name =~ s/$out//;
        return lcfirst $name;
    }
}

sub subout_op($) {
    my $out = shift;
    return sub($) {
        my $name = subout($out)->(shift);
        $name =~ s/^(fP|gEP|nUW)/\u$1/;
        $name =~ s/^(switch|cast)/$1_/;
        return $name;
    }
}

sub subout_global($) {
    my $out = shift;
    sub ($) {
        my $name = subout($out)->(shift);
        $name =~ s/delete/eraseFromParent/g; # like c++ version
        return $name;
    }
}

# metadata about classes
my %class = (
    Context => {
        method_name => subout('(?:In)?[Cc]ontext')
    },
    User => { parent => 'Value' },
    Instruction => { parent => 'User' },
    CallInst => { parent => 'Instruction' },
    Constant => {
        parent => 'User',
        method_name => subout_op('const'),
    },
    GlobalValue => {
        parent => 'Constant',
        method_name => subout('Global'),
    },
    Function => {
        parent => 'GlobalValue',
        method_name => subout_global('Function'),
    },
    GlobalVariable => {
        parent => 'GlobalValue',
        method_name => subout_global('Global'),
    },
    BasicBlock => {
        parent => 'Value',
        method_name => subout_global('[bB]asicBlock'),
        no_constructor => 1,
    },
    Builder => {
        method_name => subout_op('build|Builder')
    },
    Value => {
        method_name => subout('[Vv]alue')
    },
    Use => {},
    Type => {},
    Module => {
        method_name => subout('(?:For)?Module'),
    },
    StructType => {
        parent => 'Type',
        method_name => subout('[Ss]truct'),
    },
    IntegerType => {
        parent => 'Type',
        method_name => subout('Int'),
    },
    RealType => {
        parent => 'Type',
        method_name => subout('Real'),
    },
    FunctionType => {
        parent => 'Type',
        method_name => subout('Function'),
    },
    PassManager => {
        method_name => subout('PassManager'),
    },
    # execution engine
    GenericValue => {
        method_name => subout('[Gg]enericValue'),
    },
    ExecutionEngine => {
        method_name => subout('[Ee]xecutionEngine'),
    },
    # execution engine
    TargetData => {},
);

# metadata about methods
my $no_optional_name = 'BuildGlobalString|Name|AddGlobal|SetGC|AddAlias$';
my $not_method = '[gG]enericValue(Of|To)|FunctionType|ModuleProvider';

# turn c types into equivalent d types
sub clean_types($) {
    my $_ = shift;
    s/unsigned long long/ulong/g;
    s/long long/long/g;
    s/unsigned/uint/g;
    s/uint64_t/ulong/g;
    s/uint8_t/ubyte/g;
    s/\* *const *\*/**/g;
    s/align/algn/g;  # used as parameter name, keyword in d
    return $_;
}

# iterate over arguments in array
sub foreach_arg {
    my ($param, $sub) = @_;
    while ($param =~ /(\w+)(?:, ?| = [^,]+|$|\[\])/g) { $sub->($1); }
}

# takes a parameter list string and returns a list of just the arguments
# without the types also as a string
sub get_fwd_args($) {
    my $param = shift;
    my @argNames;
    # while ($param =~ /(\w+)(?:, ?| = [^,]+|$|\[\])/g) { push @argNames, $1; }
    foreach_arg($param, sub { push @argNames, $1; });
    return join ', ', @argNames;
}

# get a pointer to the method list of a class
sub get_class(\%$) {
    my ($out, $name) = @_;

    if (! $out->{'classes'}{$name}) {
        $out->{'classes'}{$name} = { methods => [] };
    }
    return $out->{'classes'}{$name};
}

# takes a c method description and sees if it can fit it into one of the
# object oriented wrapper classes as a method.
sub make_method_arguments($$) {
    my ($param, $fwdArgs) = @_;

    while ($param =~ /(LLVM(\w+)Ref) (\w+)/g) {
        my ($cType, $clss, $arg) = ($1, $2, $3);
        $fwdArgs =~ s/($arg)(,|$)/$1.c$2/;

        # TODO: there are more exceptions
        if ($clss eq 'Value') {
            if ($arg eq 'Global') {
                $clss = 'GlobalVariable';
            }
            elsif ($arg eq 'Fn') {
                $clss = 'Function';
            }
            elsif ($arg eq 'RHSConstant' || $arg eq 'ConstantVal') {
                $clss = 'Constant';
            }
        }

        $param =~ s/$cType/$clss/;
    }

    return ($param, $fwdArgs);
}

sub make_method_return($$) {
    my ($name, $ret) = @_;
    if ($name eq 'addFunction') {
        return 'Function';
    }
    elsif ($name eq 'addGlobal') {
        return 'GlobalVariable';
    }
    elsif ($name =~ /^const/) {
        return 'Constant';
    }
    elsif ($name =~ 'int\d+Type') {
        return 'IntegerType';
    }
    elsif ($ret =~ /^LLVM(\w+)Ref$/) {
        return $1;
    }
    elsif ($ret =~ /^LLVMBool$/) {
        return 'bool';
    }
    else {
        return undef
    }
}

# attempt to make a method or factory
sub make_method($$$$;$) {
    my ($out, $ret, $origName, $param, $fwdArgs) = @_;
    $ret =~ s/ +$//;

    # fwdArgs = how to forwards arguments from D to C in method body

    return if $origName =~ /$not_method/;

    $fwdArgs = get_fwd_args $param unless $fwdArgs;

    my $className;
    if ($origName =~ /^LLVM(GetOperand|SetOperand|GetNumOperands)$/) {
        $className = 'User';
    }
    elsif ($param =~ /^LLVMValueRef +Val/) {
        $className = 'Value';
    }
    elsif ($param =~ /^LLVMValueRef +(ConstantVal|LHSConstant)/) {
        $className = 'Constant';
    }
    elsif ($param =~ /^LLVMValueRef +GlobalVar/) {
        $className = 'GlobalVariable';
    }
    elsif ($param =~ /^LLVMBasicBlockRef +\w+/) {
        $className = 'BasicBlock';
    }
    elsif ($param =~ /^LLVMValueRef +Global/) {
        $className = 'GlobalValue';
    }
    elsif ($param =~ /^LLVMValueRef +Fn/) {
        $className = 'Function';
    }
    elsif ($param =~ /^LLVMValueRef +(Instr|CallInst)/) {
        $className = 'CallInst';
    }
    elsif ($param =~ /^LLVMValueRef +Inst/) {
        $className = 'Instruction';
    }
    elsif ($param =~ /^LLVMBuilderRef +B/) {
        $className = 'Builder';
    }
    elsif ($param =~ /^LLVMUseRef +U/) {
        $className = 'Use';
    }
    elsif ($origName eq  'LLVMGetStructName' ||
           $param =~ /^LLVMTypeRef StructTy/)
    {
        $className = 'StructType';
    }
    elsif ($param =~ /^LLVMTypeRef IntTy/) {
        $className = 'IntegerType';
    }
    elsif ($param =~ /^LLVMTypeRef RealTy/) {
        $className = 'RealType';
    }
    elsif ($param =~ /^LLVMTypeRef FunctionTy/) {
        $className = 'FunctionType';
    }
    elsif ($param =~ /^LLVMTypeRef +\w+/) {
        $className = 'Type';
    }
    elsif ($param =~ /^LLVMContextRef +C/) {
        $className = 'Context';
    }
    elsif ($param =~ /^LLVMModuleRef +M/) {
        $className = 'Module';
    }
    elsif ($param =~ /^LLVMPassManagerRef +\w+/) {
        $className = 'PassManager';
    }
    elsif ($param =~ /^LLVMGenericValueRef +\w+/) {
        $className = 'GenericValue';
    }
    elsif ($param =~ /^LLVMExecutionEngineRef +\w+/) {
        $className = 'ExecutionEngine';
    }
    elsif ($param =~ /^LLVMTargetDataRef +\w+/) {
        $className = 'TargetData';
    }
    return unless $className;

    my $methods = get_class(%$out, $className)->{'methods'};

    # remove first argument
    foreach (($param, $fwdArgs)) { s/^[^,]+(?:,|$) *//g; }
    (my $name = $origName) =~ s/^LLVM(.)/\l$1/;

    # custom substitutions on name
    if (my $method_name = $class{$className}{'method_name'}) {
        $name = &$method_name($name);
    }
    $name =~ s/^const$/$&_/g;

    # TODO: substitutute LLVM/Ref out of parameter types

    my ($param, $fwdArgs) = make_method_arguments $param, $fwdArgs;
    my $m = {
        name     => $name,
        param    => $param,
        fwdArgs  => $fwdArgs,
        origName => $origName,
    };
    push @$methods, $m;

    my $newRet = make_method_return $name, $ret;
    if (! $newRet) {
        $m->{'ret'} = $ret;
    }
    else {
        $m->{'origRet'} = $ret;
        $m->{'ret'} = $newRet;
    }
}

# scans a function and detect if it can make any of the arguments optional
# automatically, then stores it for output to the body of the capi module.
# potentially makes a second wrapper method which will convert d
# strings/arrays into underlying pointer + length arguments.
sub make_function(\%$$$) {
    my ($out, $ret, $name, $param) = @_;
    $ret =~ s/^const char/constchar/g; # d return type problem with const char
    $ret =~ s/static inline //g;

    my $has_body = $param =~ s/{//;

    $param =~ s/\);?(.*)//;
    my $comments = $1;

    $param =~ s/,\s+const char \*Name$/$& = ""/
        unless $name =~ /$no_optional_name/;

    $param =~ s/LLVMBool (DontNullTerminate|IsVarArg|SignExtend|Packed)/$& = false/;
    $param =~ s/^void$//;

    # type-only argument prototype interferes with argument forwarding,
    # although this will only be necessary if any forwarders are generated
    $param =~ s/LLVMBuilderRef(,|$)/LLVMBuilderRef B$1/;
    $param =~ s/LLVMAttribute(,|$)/LLVMAttribute A$1/;
    $param =~ s/LLVMTargetDataRef(,|$)/LLVMTargetDataRef TD$1/;
    $param =~ s/LLVMPassManagerRef(,|$)/LLVMPassManagerRef PM$1/;
    $param =~ s/LLVMTypeRef(,|$)/LLVMTypeRef Ty$1/;

    push @{$out->{'body'}}, "$ret$name($param)" . ($has_body ? " {\n" : ";$comments\n");

    return make_method($out, $ret, $name, $param)
        if $has_body or not $param =~ /(?:,|^) *([^,]*\* *\w+ *, *uint \w+)/;

    # possible pointer + length, can add conversion from array/string
    my $mod = $1;

    # TODO: deal with
    # LLVMValueRef LLVMConstIntOfArbitraryPrecision(LLVMTypeRef IntTy, uint NumWords, const ulong Words[]);
    # *sigh*

    my $fwdArgs = get_fwd_args $param;

    my ($ptrName, $dType);
    if ($mod =~ /^const char ?\* ?(\w+)/) {
        $dType = 'string';
        $ptrName = $1;
    }
    else {
        $mod =~ /^(\w+) ?\* ?(\w+)/;
        $dType = $1 . '[]';
        $ptrName = $2;
    }

    $param =~ s/\Q$mod\E/$dType $ptrName/g;
    $fwdArgs =~ s/$ptrName, \w+/$ptrName.ptr, cast(uint)$ptrName.length/;

    make_method $out, $ret, $name, $param, $fwdArgs;

    push @{$out->{'fwds'}},
         "\n\n$ret$name($param) {\n    return $name($fwdArgs);\n}";
}

# tries to match one or more c functions, returning false if it doesn't.
sub match_functions($\%$) {
    my ($fh, $out, $_) = @_;
    return 0 unless /((?:\w\s*)+[*\s])(\w+)\((.*)/;

    # have a function

    my ($ret, $name, $param) = (clean_types($1), $2, $3);

    if ($param !~ /\)/) {
        # argument list spans multiple lines
        while (<$fh>) {
            chomp;
            $param .= $_;
            $param =~ s/\s+/ /g;
            last if /\)/;
        }
    }

    $param = clean_types $param;
    # TODO: look through $param and see whether to add class method

    if ($param =~ /;\s*(\w.*)/) {
        my $after = $1;
        $param =~ s/;.*/;/;
        make_function %$out, $ret, $name, $param;
        match_functions($fh, $out, $after);
    }
    else {
        make_function %$out, $ret, $name, $param;
    }

    return 1;
}

# match c enum or return false. modifies enum options to remove prefixes
# as d scopes them inside the name of the enum.
sub match_enum($\%$) {
    my ($fh, $out, $_) = @_;
    return 0 unless /typedef enum/;

    my @enum;
    while (<$fh>) {
        if (/^\s*}\s*(\w+)/) {
            push @{$out->{'body'}}, "enum $1 {\n";
            (my $sfx = $1) =~ s/LLVM//;
            $sfx =~ s/Predicate/(Predicate)?/;
            $sfx =~ s/ClauseTy/(ClauseTy)?/;

            foreach (@enum) {
                # clean up enum values as D scopes them better than c
                s/LLVM//;
                s/$sfx//;
            }
            last;
        }
        push @enum, $_;
    }

    push @{$out->{'body'}}, @enum;
    push @{$out->{'body'}}, "}\n";
}

# output method parsed from file earlier into current class being output
sub output_method($$) {
    my ($wfh, $m) = @_;
    my $name = $m->{'name'};

    if ($name =~ /^isA/) {
        # TODO: cast to underlying type
        print $wfh "    bool $name($m->{param}) {\n";
        print $wfh "        return $m->{origName}(c) != null;\n";
        print $wfh "    }\n\n";
        return
    }

    my $fwdArgs = 'c';
    $fwdArgs .= ", $m->{fwdArgs}" if $m->{'fwdArgs'};

    my $ret = $m->{'ret'};
    my ($sfx, $prfx);
    if (my $origRet = $m->{'origRet'}) {
        if ($origRet eq 'LLVMBool') {
            $sfx = ' != 0';
            $ret = 'bool';
        }
        else {
            $prfx = "new $ret(";
            $sfx = ')';
        }
    }

    print $wfh "    $ret $name($m->{param}) {\n";
        print $wfh "        return $prfx$m->{origName}($fwdArgs)$sfx;\n";
    print $wfh "    }\n\n";
    # ...
}

sub output_constructor($$) {
    my ($wfh, $c) = @_;

    print $wfh "    this($c->{param}) {\n";
    print $wfh "        c = $c->{name}($c->{fwdArgs});\n";
    print $wfh "    }\n\n";
}

sub output_factory($$$) {
    my ($wfh, $className, $f) = @_;

    print $wfh "\n$className $f->{name}($f->{param}) {\n";
    print $wfh "    return new $className($f->{origName}($f->{fwdArgs}));\n";
    print $wfh "}\n";
}

# output class parsed from file earlier into object oriented wrapper module
# currently being output
sub output_class(\%$$) {
    my ($classes, $wfh, $name) = @_;
    my $clss = $classes->{$name};
    return if $clss->{'done'};

    my $meta = $class{$name};
    my $parent = $meta->{'parent'};
    my $llvmType = $parent || $name;

    output_class($classes, $wfh, $parent) if ($parent);

    print $wfh "\ntemplate ${name}Mixin() {\n";
    if (! $parent) {
        print $wfh "    alias LLVM${llvmType}Ref CType;\n\n";
        print $wfh "    CType c;\n\n";
        print $wfh "    this(CType c_ = null) { c = c_; };\n\n"
            unless $meta->{'no_constructor'};
    }
    else {
        print $wfh "    this(CType c_ = null) { super(c_); };\n\n"
            unless $meta->{'no_constructor'};
    }

    print $wfh "    bool empty() { return c != null; };\n\n" unless $parent;

    my $methods = $clss->{'methods'};
    foreach (@$methods) { output_method $wfh, $_; }

    print $wfh "}\n";

    $clss->{'done'} = 1;
}

sub each_path($\&) {
    my ($path, $callback) = @_;

    open my $fh, "cpp -C $path |" || die "could not open file";
    &$callback($_, $path, $fh) while (<$fh>);
    close $fh;
}

# convert a llvm-c/${Module_name}.c file into
#     gen/${module_name}.d
#         wraps the capi directly with a few additonal forwarding helpers
#         for things like arrays and strings.
#     gen/${module_name}_obj.d
#         d object oriented wrapper to recreate c++ API a bit.
sub gen_module($) {
    my $module = shift;
    my %out = (
        body => [],
        fwds => [],
        classes => {}
    );
    (my $file = $module) =~ s/(?:^|_)(\w)/\U$1/g;
    my $path = $basedir . $file . '.h';

    my $on = 0;

    my @types;

    # -C keeps comments
    # open my $fh, "cpp -C $path |" || die "could not open file";
    # while (<$fh>) {
    my $matcher = sub {
        my ($_, $path, $fh)  = @_;
        # ignore functions not in file being processed
        if (/^# \d+ "([^"]+)"/) {
            my $pp = $1;
            $on = ($pp =~ /^$path/);
            if (! $on && $module eq 'target') {
                # special exception for this module.. generated file includes
                # macro that generates the contents of several functions.
                $on = ($pp =~ /Targets\.def$/);
                if ($on) {
                    # skip annoying repeated comments
                    while (<$fh>) { last unless m,\s*[\\|/],; }
                }
            }
            return;
        }
        return unless $on;

        if (/typedef\s+struct\s+(\w+)/) {
            push @types, $1;
            s/typedef struct/alias/;
        }
        elsif (match_enum $fh, %out, $_) {
            return;
        }
        elsif (match_functions $fh, %out, $_) {
            return;
        }
        else {
            s/typedef/alias/;
        }

        push @{$out{'body'}}, $_;
    };

    each_path $path, &$matcher;

    if ($module eq 'core') {
        $on = 0;
        $path = "${basedir}BitWriter.h";
        each_path $path, &$matcher;
    }

    my $extra = $module eq 'core' ? '' : "import bustin.gen.capi.core;\n";
    $extra .= "import bustin.gen.capi.target;\n" if $module eq 'execution_engine';

    my $capiPath = "$outdir/capi";
    -e $capiPath or make_path $capiPath  or die $!;
    open my $wfh, '>', "$capiPath/$module.d" or die "could not open file for write";

    print $wfh <<EOF
// this is a generated file, please do not edit it
module bustin.gen.capi.$module;
$extra
// d has a problem with "const char *" as a return type
alias const char constchar;

extern (C) {
EOF
    ;

    foreach (@types) {
        print $wfh "struct $_;\n";
    }
    print $wfh join("", @{$out{'body'}});
    print $wfh "\n} // end extern C";
    print $wfh join("", @{$out{'fwds'}});
    close $wfh;

    # now output wrapped classes if there are any
    return unless %{$out{'classes'}};

    $extra =~ s/\.capi//; # same includes but non-capi versions
    open my $wfh, '>', "$outdir/$module.d"
        or die "could not open file for write";

    print $wfh <<EOF
// this is a generated file, please do not edit it
module bustin.gen.$module;
import bustin.gen.capi.$module;
$extra
EOF
    ;

    my $classes = $out{'classes'};
    while (my ($name, $clss) = each %$classes) {
        output_class %$classes, $wfh, $name;
    }
    close $wfh;
}

# first line of code run
@ARGV = ('core', 'execution_engine', 'target') unless @ARGV;
foreach (@ARGV) { gen_module $_; }
