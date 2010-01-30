package TestUtils;

use Test::More;

use Exporter;
use base 'Exporter';

use strict;
use warnings;

our @EXPORT = qw/plan_if_ryan52 is_ryan52 apocal_if_ryan52 mychomp/;

sub plan_if_ryan52 {
  my $tests = shift;
  if(is_ryan52()) {
    plan tests => $tests;
  } else {
    plan skip_all => 'Not Ryan52';
  }
}

sub is_ryan52 {
  return if($ENV{NOT_RYAN52});
  my $hostname = `hostname -f`;
  my $username = `id -un`;
  chomp($hostname);
  chomp($username);
  my $teststring = "$username\@$hostname";
  return $teststring eq "ryan52\@jade.home";
}

sub myslurp {
  my $filename = shift;
  # TODO
}

sub mytouch {
  # TODO
}

sub mychomp {
    my $str = shift;
    $str =~ s/[\r]//g;
    chomp($str);
    return $str;
}

sub apocal_if_ryan52 {
  if(!is_ryan52()) {
    plan skip_all => 'Not Ryan52';
    return;
  }
  if($ENV{NO_APOCAL}) {
    plan skip_all => 'NO_APOCAL is set';
    return;
  }
  $ENV{RELEASE_TESTING} = 1;
  require Test::NoWarnings; require Test::Pod; require Test::Pod::Coverage;
  eval "use Test::Apocalypse";
  if($@) {
    die($@);
  }
  is_apocalypse_here();
}

1;

