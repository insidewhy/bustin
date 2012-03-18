#!/usr/bin/env perl

use strict;

my $prfx = '/usr/include/llvm-c/';
my $file = $ARGV[0] || '/usr/include/llvm-c/Core.h';
my $on = 0;

my @types;
my @body;

# -C keeps comments
open FH, "cpp -C $file |" || die "could not open file";
while (<FH>) {
    if (/^# \d+ "([^"]+)"/) {
        $on = ($1 =~ /^$prfx/);
        next;
    }
    next unless $on;

    if (/typedef\s+struct\s+(\w+)/) {
        push @types, $1;
        s/typedef struct/alias/;
    }
    elsif (/typedef enum/) {
        my @enum;
        while (<FH>) {
            if (/^\s*}\s*(\w+)/) {
                push @body, "enum $1 {\n";
                last;
            }
            push @enum, $_;
        }

        push @body, @enum;
        push @body, "}\n";
        next;
    }
    else {
        s/typedef/alias/;
    }

    s/\(\s*void\s*\)/()/g; # d doesn't support main(void) etc.
    s/unsigned long long/ulong/g;
    s/^const char/constchar/g; # d return type problem with const char
    s/long long/long/g;
    s/unsigned/uint/g;
    s/uint64_t/ulong/g;
    s/uint8_t/ubyte/g;
    s/align/algn/g;  # used as parameter name, keyword in d

    push @body, $_;
}

print <<EOF
// this is a generated file, please do not edit it
module bustin.capi;

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
