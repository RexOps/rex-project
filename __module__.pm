#
# (c) FILIADATA GmbH
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Project;

use Moose;
use feature 'state';

use common::sense;
use Moose;
use File::Spec;
use Hash::Merge 'merge';

use Rex::Commands::Fs;
use Rex::Commands::Run;
use Rex::Commands -no => [
  qw/
    no_ssh
    desc
    group
    batch
    user
    password
    auth
    port
    sudo_password
    timeout
    max_connect_retries
    get_random
    public_key
    private_key
    pass_auth
    key_auth
    krb5_auth
    parallelism
    proxy_command
    set_distributor
    template_function
    logging
    needs
    include
    environment
    path
    set
    get
    before
    after
    around
    before_task_start
    after_task_finished
    logformat
    log_format
    cache
    profiler
    report
    source_global_profile
    last_command_output
    case
    set_executor_for
    tmp_dir
    inspect
    evaluate_hostname
    get_environment
    get_environments
    sayformat
    say_format
    make
    /
];
use Data::Dumper;

use overload
  'eq' => sub { shift->is_eq(@_); },
  'ne' => sub { shift->is_ne(@_); },
  '""' => sub { shift->to_s(@_); };

# load app types
require Application::Tomcat;
require Application::PHP::FPM;
require Application::PHP;
require Application::Static;

state @app_types;

# static method to register app types
sub register_app_type {
  my ( $class, $order, $type, $code ) = @_;
  push @app_types,
    {
    order => $order,
    class => $type,
    code  => $code,
    };
}

has srv_root_path => (
  is      => 'ro',
  default => sub {
    return "/srv";
  }
);

has deploy_start_time => (
  is => 'ro',
  default => sub { time },
);

has name => (
  is      => 'ro',
  lazy    => 1,
  default => sub {
    my ($self) = @_;

    my @entries = grep {
      $_ !~ m/(^\.|^lost\+found)/
        && is_dir( File::Spec->catdir( $self->srv_root_path, $_ ) )
    } list_files $self->srv_root_path;

    if ( scalar @entries == 1 ) {
      return $entries[0];
    }
    else {
      die "Can't detect project name. There are multiple folders in "
        . $self->srv_root_path
        . "\nPlease remove them if not needed or specify the project name manually.\n";
    }
  },
);

has project_path => (
  is      => 'ro',
  lazy    => 1,
  default => sub {
    my ($self) = @_;
    return File::Spec->catdir( $self->srv_root_path, $self->name );
  }
);

has application => (
  is      => 'ro',
  lazy    => 1,
  default => sub {
    my ($self) = @_;

    for my $app_type_c ( sort { $a->{order} <=> $b->{order} } @app_types ) {
      my $ret = $app_type_c->{code}->();
      if ($ret) {
        return $app_type_c->{class}->new(
          project => $self,
          ( $ENV{instance_prefix} ? ( name => $ENV{instance_prefix} ) : () )
        );
      }
    }

    confess "Can't detect type of application.";
  },
);

has vhost => (
  is       => 'ro',
  required => 0,
);

has configuration_template_variables => (
  is      => 'ro',
  default => sub {
    return Rex::Commands::connection()->server;
  },
);

#
# important:
# only can be called if connected to server
has is_multi_instance => (
  is      => 'ro',
  lazy    => 1,
  default => sub {
    my ($self) = @_;
    if ( !Rex::is_ssh() ) {
      confess "Only can be called remotely.";
    }

    my @instances = $self->application->get_instances();
    if ( scalar(@instances) > 1
      || ref $instances[0] eq "Application::PHP::FPM::Instance" )
    {
      return 1;
    }

    return 0;
  },
);

sub defaults {
  my ( $self, $_def ) = @_;

  $self->{__defaults__} ||= {};

  if ($_def) {
    $self->{__defaults__} = merge( $_def, $self->{__defaults__} );
  }
  else {
    merge(
      $self->{__defaults__},
      {
        instance_path =>
          File::Spec->catdir( $self->project_path, "www", ($self->vhost || "default") ),
        document_root_directory        => "app",
        deploy_stash_directory         => "deploy",
        deploy_configuration_directory => "conf",
        data_directory                 => "shared",
        manager_path                   => "manager",
      },
    );
  }
}

sub to_s {
  my ($self) = @_;
  return $self->name;
}

sub is_eq {
  my ( $self, $comp ) = @_;
  if ( $comp eq $self->to_s ) {
    return 1;
  }
}

sub is_ne {
  my ( $self, $comp ) = @_;
  if ( $comp ne $self->to_s ) {
    return 1;
  }
}

sub deploy {
  my ( $self, %param ) = @_;

  $self->pre_check_systems(%param);

  $self->prepare(%param);

  if ( exists $param{test} ) {
    $self->test(%param);
  }

  $self->switch(%param);

  if ( $param{purge_inactive} ) {
    $self->purge_inactive(%param);
  }
}

sub pre_check_systems {
  my ( $self, %param ) = @_;
  do_task "Project:Tasks:pre_check_systems", { %param, project => $self };
}

sub prepare {
  my ( $self, %param ) = @_;
  do_task "Project:Tasks:prepare", { %param, project => $self };
}

sub test {
  my ( $self, %param ) = @_;
  do_task "Project:Tasks:test", { %{ $param{test} }, project => $self };
}

sub switch {
  my ( $self, %param ) = @_;
  do_task "Project:Tasks:switch", { %param, project => $self };
}

sub purge_inactive {
  my ( $self, %param ) = @_;
  do_task "Project:Tasks:purge_inactive", { %param, project => $self };
}

1;
