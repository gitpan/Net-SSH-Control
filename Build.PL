use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Net::SSH::Control',
    license             => 'perl',
    dist_author         => 'Ryan Niebur <ryanryan52@gmail.com>',
    dist_version        => '0.01',
    dist_abstract       => 'SSH Magic',
    requires => {
          'perl' => '5.008',
          'Devel::GlobalDestruction' => 0,
          'Capture::System' => 0
        },
    build_requires => {
          'Test::More' => 0,
          'Test::Timeout' => 0
        },
    add_to_cleanup      => [ 'Net-SSH-Control-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
