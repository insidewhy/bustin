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
    Module => {},
    Type => {},
    Value => {},
    BasicBlock => {},
    Builder => {},
    ModuleProvider => {},
    MemoryBuffer => {},
    PassManager => {},
    PassRegistry => {},
    Use => {}
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

sub make_function(\%$$$) {
    my ($out, $ret, $name, $param) = @_;
    $ret =~ s/^const char/constchar/g; # d return type problem with const char
    $ret =~ s/static inline //g;

    my $has_body = $param =~ s/{//;

    $param =~ s/\);?(.*)//;
    my $comments = $1;

    $param =~ s/,\s+const char \*Name$/$& = ""/
        unless $name =~ /$no_optional_name/;

    $param =~ s/LLVMBool (DontNullTerminate|IsVarArg|SignExtend)/$& = false/;
    $param =~ s/^void$//;

    push @{$out->{'body'}}, "$ret$name($param)" . ($has_body ? " {\n" : ";$comments\n");
    # todo: build class version

    return if $has_body;
    # possible pointer + length, can add conversion from array/string
    return unless $param =~ /(?:,|^) *([^,]*\* *\w+ *, *uint \w+)/;

    my $mod = $1;
    my @argNames;

    # type-only argument prototype interferes with argument forwarding
    $param =~ s/LLVMBuilderRef,/LLVMBuilderRef B,/;

    while ($param =~ /(\w+)(?:, ?| = [^,]+|$)/g) { push @argNames, $1; }
    my $fwdArgs = join ', ', @argNames;

    my ($modParam, $ptrName, $dType);
    $modParam = $param;
    if ($mod =~ /^const char ?\* ?(\w+)/) {
        $dType = 'string';
        $ptrName = $1;
    }
    else {
        $mod =~ /^(\w+) ?\* ?(\w+)/;
        $dType = $1 . '[]';
        $ptrName = $2;
    }

    $modParam =~ s/\Q$mod\E/$dType $ptrName/g;
    $fwdArgs =~ s/$ptrName, \w+/$ptrName.ptr, cast(uint)$ptrName.length/;
    push @{$out->{'fwds'}},
         "\n\n$ret$name($modParam) {\n    return $name($fwdArgs);\n}";
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
    foreach (keys %class) {
        $out{classes}{$_} = {};
    }

    # -C keeps comments
    open my $fh, "cpp -C $path |" || die "could not open file";
    while (<$fh>) {
        # ignore functions not in file being processed
        if (/^# \d+ "([^"]+)"/) {
            my $pp = $1;
            $on = ($pp =~ /^$path/);
            if (! $on && $module eq 'target') {
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
}

@ARGV = ('core', 'execution_engine', 'target') unless @ARGV;
foreach (@ARGV) { gen_module $_; }
