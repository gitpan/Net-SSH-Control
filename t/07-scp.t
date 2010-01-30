use Test::More;
use strict;
use warnings;

use File::Basename;
use File::Spec;

use lib File::Spec->catfile(File::Basename::dirname(__FILE__), "lib");
use TestUtils;

plan_if_ryan52(15);

# TODO: test scp-ing back to the local machine

# TODO: test scp-ing multiple files (both ways)

use Net::SSH::Control;
my $ssh = Net::SSH::Control->new("reiche.home.");
is($ssh->start_ssh()->status(), 0);
is($ssh->started(), 1);
is($ssh->check(), 1);
is($ssh->ssh("rm -f testfile")->status(), 0);
is($ssh->ssh("test -f testfile")->status(), 1);
unlink("testfile");
my $res = $ssh->scp("testfile", ">");
is($res->status(), 1);
is(mychomp($res->stderr()), "testfile: No such file or directory");
is($ssh->ssh("test -f testfile")->status(), 1);
system("touch", "testfile");
$res = $ssh->scp("testfile", ">");
is($res->status(), 0);
is($ssh->ssh("test -f testfile")->status(), 0);
is($ssh->ssh("rm testfile")->status(), 0);
is($ssh->ssh("rm -f foobaz-testfile")->status(), 0);
is($ssh->ssh("test -f foobaz-testfile")->status(), 1);
$res = $ssh->scp("testfile", ">", "/home/ryan52/foobaz-testfile");
is($ssh->ssh("test -f foobaz-testfile")->status(), 0);
is($ssh->ssh("rm foobaz-testfile")->status(), 0);
unlink("testfile");
