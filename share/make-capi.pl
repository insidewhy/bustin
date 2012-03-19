#!/usr/bin/env perl

# hacky perl script, the llvm authors are pretty consistent with their
# formatting so this doesn't have to be perfect

use strict;

my $basedir = '/usr/include/llvm-c/';

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
    s/^const char/constchar/g; # d return type problem with const char
    s/long long/long/g;
    s/unsigned/uint/g;
    s/uint64_t/ulong/g;
    s/uint8_t/ubyte/g;
    s/align/algn/g;  # used as parameter name, keyword in d
    return $_;
}

sub match_function($\@$) {
    my ($fh, $body, $_) = @_;
    # $_ = clean_types $_;
    return 0 unless /((?:\w\s*)+[*\s])(\w+)\((.*)/;

    # have a function

    my ($ret, $name, $param) = (clean_types($1), $2, $3);

    if ($param eq 'void);') {
        push @$body, "$ret$name();\n";
        return 1; # there's never anything after for now
    }

    if ($param !~ /\)/) {
        while (<$fh>) {
            $param .= $_;
            $param =~ s/\s+/ /g;
            last if /\)/;
        }
        # more lines to read
    }

    $param = clean_types $param;

    if ($param =~ /;\s*(\w.*)/) {
        my $after = $1;
        $param =~ s/;.*/;/;
        push @$body, "$ret$name($param\n";
        match_function($fh, $body, $after);
    }
    else {
        push @$body, "$ret$name($param\n";
    }

    print STDERR "$ret$name($param\n";

    # TODO: if no ) in $param then look for more arguments
    # TODO: see if there are more functions after ;

    return 1;
}

sub gen_module($) {
    my $module = shift;
    my $file = $basedir . ucfirst($module) . '.h';

    my $on = 0;

    my @types;
    my @body;

    # -C keeps comments
    open my $fh, "cpp -C $file |" || die "could not open file";
    while (<$fh>) {
        # ignore functions not in file being processed
        if (/^# \d+ "([^"]+)"/) {
            $on = ($1 =~ /^$file/);
            next;
        }
        next unless $on;

        if (/typedef\s+struct\s+(\w+)/) {
            push @types, $1;
            s/typedef struct/alias/;
        }
        elsif (/typedef enum/) {
            my @enum;
            while (<$fh>) {
                if (/^\s*}\s*(\w+)/) {
                    push @body, "enum $1 {\n";
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

            push @body, @enum;
            push @body, "}\n";
            next;
        }
        elsif (match_function $fh, @body, $_) {
            next;
        }
        else {
            s/typedef/alias/;
        }

        push @body, clean_types($_);
    }

    print <<EOF
// this is a generated file, please do not edit it
module bustin.gen.$module;

// d has a problem with "const char *" as a return type
alias const char constchar;

extern (C) {
EOF
    ;

    foreach (@types) {
        print "extern struct $_;\n";
    }
    print(join("", @body));

    print "\n} // end extern C";
}

if (! @ARGV) {
    gen_module 'core';
}
else {
    foreach (@ARGV) { gen_module $_; }
}
