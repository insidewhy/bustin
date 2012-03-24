#!/usr/bin/env perl

# hacky perl script, the llvm authors are pretty consistent with their
# formatting so this doesn't have to be perfect

use strict;

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
        $name =~ s/^(switch|cast)/$out\u$1/;
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
        super => 'LLVMBasicBlockAsValue(c_)',
    },
    Builder => {
        method_name => subout_op('build')
    },
    Value => {
        method_name => subout('[Vv]alue')
    },
    Use => {},
    Type => {},
);

# metadata about methods
my $no_optional_name = 'BuildGlobalString|Name|AddGlobal|SetGC|AddAlias$';
my $not_method = '[gG]enericValue';

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

# takes a parameter list string and returns a list of just the arguments
# without the types also as a string
sub get_fwd_args($) {
    my $param = shift;
    my @argNames;
    while ($param =~ /(\w+)(?:, ?| = [^,]+|$|\[\])/g) { push @argNames, $1; }
    return join ', ', @argNames;
}

# get a pointer to the method list of a class
sub get_methods(\%$) {
    my ($out, $clss) = @_;

    if (! $out->{'classes'}{$clss}) {
        $out->{'classes'}{$clss} = { 'methods' => {} };
    }
    return $out->{'classes'}{$clss}{'methods'};
}

# takes a c method description and sees if it can fit it into one of the
# object oriented wrapper classes as a method.
sub make_method($$$$;$) {
    my ($out, $ret, $origName, $param, $fwdArgs) = @_;
    # fwdArgs = how to forwards arguments from D to C in method body

    return if $origName =~ /$not_method/;

    $fwdArgs = get_fwd_args $param unless $fwdArgs;

    # print STDERR "candid $ret$name($param) { $fwdArgs; }\n";
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
    elsif ($param =~ /^LLVMTypeRef +\w+/) {
        $className = 'Type';
    }
    elsif ($param =~ /^LLVMContextRef +C/) {
        $className = 'Context';
    }
    return unless $className;

    my $methods = get_methods %$out, $className;

    # remove first argument
    foreach (($param, $fwdArgs)) { s/^[^,]+(?:,|$) *//g; }
    (my $name = $origName) =~ s/^LLVM(.)/\l$1/;

    # custom substitutions on name
    if (my $method_name = $class{$className}{'method_name'}) {
        $name = &$method_name($name);
    }

    # TODO: substitutute LLVM/Ref out of parameter types
    my $m = $methods->{$name} = {
        param    => $param,
        fwdArgs  => $fwdArgs,
        origName => $origName,
    };

    # deal with return type
    $ret =~ s/ +$//;
    if ($ret =~ /^LLVM(\w+)Ref$/) {
        $ret = $1;
        $m->{'origRet'} = $&;
    }
    elsif ($ret =~ /^LLVMBool$/) {
        $ret = 'bool';
        $m->{'origRet'} = 'LLVMBool';
    }
    $m->{'ret'} = $ret;
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
    $param =~ s/LLVMBuilderRef,/LLVMBuilderRef B,/;
    $param =~ s/LLVMAttribute(,|$)/LLVMAttribute A$1/;

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
sub output_method($$$) {
    my ($wfh, $name, $m) = @_;

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
    my $sfx;
    if (my $origRet = $m->{'origRet'}) {
        if ($origRet eq 'LLVMBool') {
            $sfx = ' != 0';
            $ret = 'bool';
        }
        else {
            # TODO: wrap return value in this case
            $ret = $origRet;
        }
    }

    print $wfh "    $ret $name($m->{param}) {\n";
        print $wfh "        return $m->{origName}($fwdArgs)$sfx;\n";
    print $wfh "    }\n\n";
    # ...
}

# output class parsed from file earlier into object oriented wrapper module
# currently being output
sub output_class(\%$$) {
    my ($classes, $wfh, $name) = @_;
    my $clss = $classes->{$name};
    return if $clss->{'done'};

    my $meta = $class{$name};
    my $parent = $meta->{'parent'};
    my $realPar = $meta->{'real_parent'};
    my $llvmType = ! $realPar && $parent ? $parent : $name;

    if ($parent) {
        output_class($classes, $wfh, $parent);
        $parent = " : $parent";
    }
    else { $parent = ''; }

    print $wfh "\nclass $name$parent {\n";
    if (! $parent || $realPar) {
        print $wfh "    alias LLVM${llvmType}Ref CType;\n\n";
        print $wfh "    CType c;\n\n";
        print $wfh "    this(CType c_ = null) { c = c_; };\n\n";
    }
    else {
        print $wfh "    this(CType c_ = null) { super(c_); };\n\n";
    }

    print $wfh "    bool empty() { return c != null; };\n\n" unless $parent;

    my $methods = $clss->{'methods'};
    foreach my $mName (sort keys %$methods) {
        output_method $wfh, $mName, $methods->{$mName};
    }

    print $wfh "}\n";
    $clss->{'done'} = 1;
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
    open my $fh, "cpp -C $path |" || die "could not open file";
    while (<$fh>) {
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
            next;
        }
        next unless $on;

        if (/typedef\s+struct\s+(\w+)/) {
            push @types, $1;
            s/typedef struct/alias/;
        }
        elsif (match_enum $fh, %out, $_) {
            next;
        }
        elsif (match_functions $fh, %out, $_) {
            next;
        }
        else {
            s/typedef/alias/;
        }

        push @{$out{'body'}}, $_;
    }

    my $extra = $module eq 'core' ? '' : "import bustin.gen.core;\n";
    $extra .= "import bustin.gen.target;\n" if $module eq 'execution_engine';

    open my $wfh, '>', "$outdir/$module.d" or die "could not open file for write";

    print $wfh <<EOF
// this is a generated file, please do not edit it
module bustin.gen.$module;
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

    my $ooModule = $module . '_obj';
    $extra =~ s/;/_obj;/; # same includes but _obj versions
    open my $wfh, '>', "$outdir/$ooModule.d"
        or die "could not open file for write";

    print $wfh <<EOF
// this is a generated file, please do not edit it
module bustin.gen.$ooModule;
import bustin.gen.$module;
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
