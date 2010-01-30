use Test::More;
use strict;
use warnings;

use File::Basename;
use File::Spec;

use lib File::Spec->catfile(File::Basename::dirname(__FILE__), "lib");
use TestUtils;

plan_if_ryan52(11);

use Net::SSH::Control;
my $ssh = Net::SSH::Control->new("failme.home.");
my $res = $ssh->start_ssh();
is($res->status, 255);
is(mychomp($res->stderr()), "ssh: Could not resolve hostname failme.home.: Name or service not known");
ok(!$ssh->started());
ok(!$ssh->check());
$ssh = Net::SSH::Control->new("reiche.home.");
is($ssh->start_ssh()->status(), 0);
is($ssh->started(), 1);
is($ssh->check(), 1);
$res = $ssh->ssh({stdout => "capture"}, "hostname");
is($res->status(), 0);
is(mychomp($res->stdout()), "reiche");
$res = $ssh->ssh("false");
is($res->status, 1);
$ssh->stop_ssh();
ok(!$ssh->check());
