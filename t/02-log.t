use Test::More tests => 4;

use strict;
use warnings;

use File::Temp qw/tempfile/;

my($fh, $output) = tempfile();
close $fh;

BEGIN { use_ok( 'Log::Output' ); }
if(-f $output) {
    unlink($output);
}
sub foo {
    system("echo hi");
    system("echo hello >&2");
    return 73;
};
is(73, with_log($output, \&foo));
ok(-f $output);
my $f;
open $f, $output;
my $out = join '', <$f>;
is($out, "hi\nhello\n");
unlink($output);
