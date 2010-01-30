package Net::SSH::Control;

use File::Temp qw/tempdir/;
use File::Spec;

use strict;
use warnings;

our @keepers = ();

our $VERSION = '0.01';

=head1 NAME

Net::SSH::Control - SSH Magic

=head1 SYNOPSIS

  use Net::SSH::Control;
  my $ssh = Net::SSH::Control->new($host, $user, $port);
  my $res = $ssh->start_ssh();
  if(!$ssh->started()) {
    die($res->stderr() . "Failed to make the ssh connection, ssh's return code was: " . $res->status());
  }

=cut

# TODO: better docs

sub new {
  my $class = shift;
  my $self = {};
  $self->{ready} = 0;
  $self->{destroyed} = 0;
  ($self->{host}, $self->{user}, $self->{port}) = @_;
  $self->{tempdir} = tempdir();
  $self->{socket} = File::Spec->catfile($self->{tempdir}, "socket");
  bless $self, $class;
  return $self;
}

use Carp;
use POSIX;

sub start_ssh {
  my $self = shift;
  croak "Net::SSH::Control object cannot be reused" if($self->{destroyed} == 1);
  my @start_ssh_command = $self->_basic_ssh_command();
  my $testfile = File::Spec->catfile($self->{tempdir}, "testfile");
  push @start_ssh_command, "-o", "ControlMaster=yes", "-N", "-o", "PermitLocalCommand=yes", "-o", "LocalCommand=touch $testfile";
  my $stderr = IO::Pipe->new();
  my $pid;
  $pid = fork();
  if($pid == 0) {
    $stderr->writer();
    dup2(fileno($stderr), fileno(STDERR));
    exec(@start_ssh_command);
  }
  my $retval = 0;
  $SIG{CHLD} = sub {wait; $retval = $? >> 8;};
  $stderr->reader();
  $stderr->blocking(0);
  while(!-f $testfile && kill(0, $pid) == 1) {
    sleep(0.25);
  }
  $SIG{CHLD} = undef;
  if(-f $testfile) {
    unlink($testfile);
    while(!-e $self->socket()) { # ssh shouldn't run LocalCommand until it sets up the socket, imho. tho it does. worked around here.
      sleep(0.25);
    }
    $self->{ready} = 1;
  } else {
    $self->stop_ssh();
  }
  my $result = {};
  $result->{status} = $retval;
  $result->{stderr} = join '', <$stderr>;
  @{$result->{cmd}} = @start_ssh_command;
  $result->{pid} = $pid;
  $result->{opts} = {stderr => "capture"}; # FIXME
  $result = Capture::System->_new_from_hash($result);
  return $result;
}

sub keep {
  my $self = shift;
  push @keepers, $self;
}

sub started {
  my $self = shift;
  return $self->{ready} == 1 && $self->{destroyed} != 1;
}

use Devel::GlobalDestruction; # TODO: improve the cleanup

sub DESTROY {
  return if in_global_destruction;
  my $self = shift;
  $self->stop_ssh();
}

sub END {
  _killall_keepers();
}

sub _killall_keepers {
  while(scalar(@keepers)) {
    my $keeper = shift @keepers;
    $keeper->stop_ssh();
  }
}

sub svn_ssh_command {
  my $self = shift;
  my @svn_ssh = qw/ssh/;
  push @svn_ssh, "-S", $self->socket();
  return _a_or_s(@svn_ssh);
}

sub stop_ssh {
  my $self = shift;
  return if($self->{destroyed});
  my @stop_ssh_command = $self->_stop_ssh_command();
  my $ret = $self->_system(@stop_ssh_command);
  $self->{destroyed} = 1;
  rmdir($self->{tempdir});
  return $ret->status(); #FIXME
}

sub _stop_ssh_command {
  my $self = shift;
  my @end_ssh_command = $self->_basic_ssh_command();
  push @end_ssh_command, "-q", "-O", "exit";
  return _a_or_s(@end_ssh_command);
}

sub _check_ssh_command {
  my $self = shift;
  my @end_ssh_command = $self->_basic_ssh_command();
  push @end_ssh_command, "-q", "-O", "check";
  return _a_or_s(@end_ssh_command);
}

sub user {
  my $self = shift;
  return $self->{user};
}

sub port {
  my $self = shift;
  return $self->{port};
}

sub host {
  my $self = shift;
  return $self->{host};
}

sub socket {
  my $self = shift;
  return $self->{socket};
}

sub _ssh_command {
  my $self = shift;
  my @a = $self->_basic_ssh_command;
  my @res = (@a, @_);
  return _a_or_s(@res);
}

sub ssh {
  my $self = shift;
  my $opts = Capture::System::_default_opts();
  if(ref($_[0]) eq "HASH") {
    $opts = shift;
  }
  my @cmd = $self->_ssh_command(@_);
  $self->_ensure();
  return $self->_system($opts, @cmd);
}

# TODO: test this behavior (that it start_sshs, and that it doesn't run if already stopped)

sub _ensure {
  my $self = shift;
  if($self->check()) {
    return;
  }
  if(!$self->{ready}) {
    $self->start_ssh();
    if($self->check()) {
      return;
    }
  }
  local $Carp::CarpLevel = 1;
  croak("ssh is not running");
}

use Capture::System;

sub _system {
  if(ref($_[0]) eq "Net::SSH::Control") {
    shift;
  }
  return Capture::System->_new(@_);
}

sub scp {
  my $self = shift;
  my @cmd = $self->_scp_command(@_);
  $self->_ensure();
  return $self->_system({stderr => "capture"}, @cmd);
}

sub check {
  my $self = shift;
  my @cmd = $self->_check_ssh_command();
  my $ret = _system({stderr => "capture"}, @cmd);
  return ($ret->status() == 0);
}

sub _scp_command {
  my $self = shift;
  if(scalar(@_) != 3 && scalar(@_) != 2) {
    die("scp requires 2 or 3 arguements");
  }
  my $local = shift;
  my $direction = shift;
  my $remote = shift;
  if(!defined($remote)) {
      $remote = "";
  }
  my(@local_a, @remote_a);
  if(ref($local) eq "ARRAY") {
    @local_a = @$local;
  } else {
    @local_a = ($local);
  }
  if(ref($remote) eq "ARRAY") {
    @remote_a = @$remote;
  } else {
    @remote_a = ($remote);
  }
  if(scalar(@local_a) < 1) {
    die("Must give at least one local filename");
  }
  if(scalar(@remote_a) < 1) {
    die("Must give at least one remote filename");
  }
  if($direction eq "<") {
    if(scalar(@local_a) != 1) {
      die("When transfering to local, only one local file is allowed");
    }
  } elsif($direction eq ">") {
    if(scalar(@remote_a) != 1) {
      die("When transfering to remote, only one remote file is allowed");
    }
  } else {
    die("Unknown transfer type: $direction (valid are > and <)");
  }
  @remote_a = map {$self->host() . ":" . $_} @remote_a;
  my @cmd = $self->_basic_scp_command();
  if($direction eq "<") {
    push @cmd, @remote_a;
    push @cmd, @local_a;
  } else { # has to be ">"
    push @cmd, @local_a;
    push @cmd, @remote_a;
  }
  return @cmd;
}

sub _basic_ssh_command {
  my $self = shift;
  my $type = shift || "ssh";
  my @ssh_command = $type;
  push @ssh_command, "-o", "User=" . $self->user() if($self->user());
  push @ssh_command, "-o", "Port=" . $self->port() if($self->port());
  push @ssh_command, "-o", "ControlPath=" . $self->socket();
  if($type ne "scp") {
    push @ssh_command, $self->host();
  } else { # is scp
    push @ssh_command, "-r";
    push @ssh_command, "-q";
  }
  return _a_or_s(@ssh_command);
}

sub _basic_scp_command {
  my $self = shift;
  return $self->_basic_ssh_command("scp");
}

sub _a_or_s {
  if(wantarray()) {
    return @_;
  } else {
    return join " ", @_;
  }
}

1;
