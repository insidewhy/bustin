#!/usr/bin/env perl

# hacky perl script, the llvm authors are pretty consistent with their
# formatting so this doesn't have to be perfect

use strict;

my $basedir = '/usr/include/llvm-c/';
my $outdir = './gen/';

my $no_optional_name = 'BuildGlobalString|Name|AddGlobal|SetGC|AddAlias$';

# metadata about classes
my %class = (
    Context => {
        subout => 'InContext'
    },
);

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

sub get_fwd_args($) {
    my $param = shift;
    my @argNames;
    while ($param =~ /(\w+)(?:, ?| = [^,]+|$)/g) { push @argNames, $1; }
    return join ', ', @argNames;
}

sub get_methods(\%$) {
    my ($out, $clss) = @_;

    if (! $out->{'classes'}{$clss}) {
        $out->{'classes'}{$clss} = { 'methods' => {} };
    }
    return $out->{'classes'}{$clss}{'methods'};
}

# tries to make a d wrapper method from a known function
sub make_method($$$$;$) {
    my ($out, $ret, $origName, $param, $fwdArgs) = @_;

    $fwdArgs = get_fwd_args $param unless $fwdArgs;

    # print STDERR "candid $ret$name($param) { $fwdArgs; }\n";
    my $className;
    if ($param =~ /^LLVMValueRef +Val/) {
        $className = 'Value';
    }
    return unless $className;

    my $methods = get_methods %$out, $className;
    # remove first argument
    foreach (($param, $fwdArgs)) { s/^[^,]+(?:,|$) *//g; }
    (my $name = $origName) =~ s/^LLVM//;
    # TODO: more substitutions on name?

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

    push @{$out->{'body'}}, "$ret$name($param)" . ($has_body ? " {\n" : ";$comments\n");

    return make_method($out, $ret, $name, $param)
        if $has_body or not $param =~ /(?:,|^) *([^,]*\* *\w+ *, *uint \w+)/;

    # possible pointer + length, can add conversion from array/string
    my $mod = $1;

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
    make_method $out, $ret, $name, $param, $fwdArgs;

    $fwdArgs =~ s/$ptrName, \w+/$ptrName.ptr, cast(uint)$ptrName.length/;
    push @{$out->{'fwds'}},
         "\n\n$ret$name($param) {\n    return $name($fwdArgs);\n}";
}

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

sub output_method($$$) {
    my ($wfh, $name, $m) = @_;

    # simplify these.. no need to return value cast itself
    $name = lcfirst $name;
    if ($name =~ /^isA/) {
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

sub output_class($$$) {
    my ($wfh, $name, $meta) = @_;
    return if ($meta->{'done'});

    # TODO: see if there are parent classes to do first

    my $parentStr = '';
    print $wfh "\nclass $name$parentStr {\n";
    print $wfh "    alias LLVM${name}Ref CType;\n\n";
    print $wfh "    CType c;\n\n";
    print $wfh "    this(CType c_) { c = c_; };\n\n";

    while (my ($mName, $m) = each %{$meta->{'methods'}}) {
        output_method $wfh, $mName, $m;
    }

    print $wfh "\n}\n";

    $meta->{'done'} = 1;
}

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

    while (my ($name, $meta) = each %{$out{'classes'}}) {
        output_class $wfh, $name, $meta;
    }
    close $wfh;
}

@ARGV = ('core', 'execution_engine', 'target') unless @ARGV;
foreach (@ARGV) { gen_module $_; }
