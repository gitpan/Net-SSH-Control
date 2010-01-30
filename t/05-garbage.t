use Test::More;
use strict;
use warnings;

use File::Spec;
use File::Basename;

use lib File::Spec->catfile(File::Basename::dirname(__FILE__), "lib");
use TestUtils;

plan_if_ryan52(15);

use Net::SSH::Control;
my($ssh, $tempdir);

$ssh = Net::SSH::Control->new("failme.home.");
$ssh->start_ssh();
$tempdir = $ssh->{tempdir};
ok(!-e $tempdir);

$ssh = Net::SSH::Control->new("failme.home.");
$tempdir = $ssh->{tempdir};
undef $ssh;
ok(!-e $tempdir);

$ssh = Net::SSH::Control->new("reiche.home.");
$tempdir = $ssh->{tempdir};
ok(-d $tempdir);
$ssh->start_ssh();
my $socket = $ssh->socket();
ok(-e $socket);
$ssh->stop_ssh();
ok(!-e $socket);
ok(!-e $tempdir);

$ssh = Net::SSH::Control->new("reiche.home.");
$tempdir = $ssh->{tempdir};
ok(-d $tempdir);
$ssh->start_ssh();
$socket = $ssh->socket();
ok(-e $socket);
undef $ssh;
ok(!-e $socket);
ok(!-e $tempdir);

$ssh = Net::SSH::Control->new("reiche.home.");
$tempdir = $ssh->{tempdir};
ok(-d $tempdir);
$ssh->start_ssh();
$socket = $ssh->socket();
ok(-e $socket);
$ssh->keep();
undef $ssh;
ok(-e $socket);
Net::SSH::Control::_killall_keepers();
ok(!-e $socket);
ok(!-e $tempdir);
