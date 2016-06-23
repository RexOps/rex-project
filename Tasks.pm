#
# (c) FILIADATA GmbH
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Project::Tasks;

BEGIN {
  use Rex -base;
  use Rex::Transaction;
  use Hash::Merge 'merge';
  use File::Basename qw/dirname/;
  use File::Spec;
  use Data::Dumper;
  use Application::Download;

  my @new_inc;
  for my $i (@INC) {
    push @new_inc, $i if ( $i ne "." );
  }
  push @new_inc, ".";
  @INC = @new_inc;

  require Project;
}

my $defaults = {
  context        => "/",
  project_object => sub { Project->new(@_); },
};

my $hooks = {};

sub defaults {
  my $_def = shift;
  $defaults = merge( $_def, $defaults );
}

sub on {
  my ( $hook, $code ) = @_;
  push @{ $hooks->{$hook} }, $code;
}

task "rollout", sub {
  my $params = shift;

  set params => $params;

  my %deploy_hash = %{$params};

  if ( exists $defaults->{srv_root_path} ) {
    $project_hash{srv_root_path} = $defaults->{srv_root_path};
  }

  if ( exists $defaults->{name} ) {
    $project_hash{name} = $defaults->{name};
  }

  if ( exists $defaults->{project_path} ) {
    $project_hash{project_path} = $defaults->{project_path};
  }

  if ( exists $defaults->{configuration_template_variables} ) {
    $project_hash{configuration_template_variables} =
      $defaults->{configuration_template_variables};
  }

  my $project = $defaults->{project_object}->(%project_hash);

  if ( exists $params->{app}
    || ( $defaults->{deploy_app} && ref $defaults->{deploy_app} eq "" ) )
  {
    my $download_url;
    $params->{app} ||= $defaults->{deploy_app};
    if ( $params->{app} =~ m/^https?:\/\//
      && $defaults->{http_user}
      && $defaults->{http_password} )
    {
      my ( $proto, $host, $path ) =
        ( $params->{app} =~ m|^([^:]+)://([^/]+)(.*)$| );
      $download_url = Application::Download::URL->new(
        proto    => $proto,
        host     => $host,
        path     => $path,
        user     => $defaults->{http_user},
        password => $defaults->{http_password},
      );
    }
    else {
      $download_url = $params->{app};
    }

    $deploy_hash{deploy_app} = [
      $download_url,
      ( $params->{context} ? $params->{context} : $defaults->{context} )
    ];
  }
  elsif ( exists $defaults->{deploy_app} ) {
    $deploy_hash{deploy_app} = [
      $defaults->{deploy_app},
      ( $params->{context} ? $params->{context} : $defaults->{context} )
    ];
  }
  my @conf_arr;

  if ( exists $params->{configuration} ) {
    push @conf_arr, $params->{configuration};
  }
  elsif ( $project->get_configurations ) {
    push @conf_arr, $project->get_configurations;
  }

  $params->{"configuration-directory"} ||= $params->{"configuration_directory"};
  $params->{"configuration-directory"} ||= $defaults->{configuration_directory}
    if $defaults->{configuration_directory};

  if ( $params->{"configuration-directory"} && scalar @conf_arr == 1 ) {
    push @conf_arr, $params->{"configuration-directory"};
  }
  elsif ( scalar @conf_arr == 1 ) {
    push @conf_arr, $params->{context} ? $params->{context} : "app";
  }

  $deploy_hash{configure_app} = [@conf_arr] if @conf_arr;

  if ( exists $params->{rescue} ) {
    $deploy_hash{rescue} = [
      $params->{rescue},
      ( $params->{context} ? $params->{context} : $defaults->{context} )
    ];
  }
  elsif ( exists $defaults->{rescue} ) {
    $deploy_hash{rescue} = $defaults->{rescue};
  }

  if ( exists $params->{stop} ) {
    $deploy_hash{stop} = $params->{stop};
  }
  elsif ( exists $defaults->{stop} ) {
    $deploy_hash{stop} = $defaults->{stop};
  }

  if ( exists $params->{restart} ) {
    $deploy_hash{restart} = $params->{restart};
  }
  elsif ( exists $defaults->{restart} ) {
    $deploy_hash{restart} = $defaults->{restart};
  }

  $params->{"start-before-deploy"} ||= $params->{start_before_deploy};
  if ( $params->{"start-before-deploy"} ) {
    $deploy_hash{start_before_deploy} = $params->{"start-before-deploy"};
  }
  elsif ( exists $defaults->{start_before_deploy} ) {
    $deploy_hash{start_before_deploy} = $defaults->{start_before_deploy};
  }

  $params->{"purge-inactive"} ||= $params->{purge_inactive};
  if ( $params->{"purge-inactive"} ) {
    $deploy_hash{purge_inactive} = $params->{"purge-inactive"};
  }
  elsif ( exists $defaults->{purge_inactive} ) {
    $deploy_hash{purge_inactive} = $defaults->{purge_inactive};
  }

  $params->{"deploy-lib"} ||= $params->{"deploy_lib"};
  if ( $params->{"deploy-lib"} ) {
    $deploy_hash{deploy_lib} = $params->{"deploy-lib"};
  }

  if ( $params->{test} ) {
    $deploy_hash{test} = { location => $params->{test}, };
  }
  elsif ( $defaults->{test} ) {
    $deploy_hash{test} = { location => $defaults->{test} };
  }

  if ( $params->{vhost} && !$defaults->{vhost} ) {
    $defaults{vhost} = $params->{vhost};
  }

  # use exists if version is 0
  if ( exists $params->{version} ) {
    $defaults->{deploy_version} = $params->{version};
  }

  transaction {
    $project->defaults($defaults);

    # hook: before_task_deploy
    for my $hook ( @{ $hooks->{before_task_deploy} } ) {
      $hook->( $project, $params );
    }

    $project->deploy(%deploy_hash);
  };
};

task "pre_check_systems",
  group => "servers",
  sub {
  my $param = shift;

  my @entries;

  # find path to this module.
  my $default_tests_d = File::Spec->catdir(
    dirname( Rex::Helper::Path::get_file_path("__module__.pm") ), "tests.d" );

  LOCAL {
    push @entries, list_files $default_tests_d if ( -d $default_tests_d );
    push @entries, list_files "tests.d"        if ( -d "tests.d" );
  };

  sudo sub {
    file "/var/cache/rex/test", ensure => "directory", mode => '1777';
  };

  for my $test (@entries) {

    # rex automatically knows if it needs to upload the
    # file from lib/DM/tests.d directory or ./tests.d directory
    # files from ./tests.d has precedence
    file "/var/cache/rex/test/$test",
      source => "tests.d/$test",
      mode   => '0755';

    my $output = run "/var/cache/rex/test/$test 2>&1";

    if ( $? != 0 ) {
      die "Error running test $test. Exit Code: $?.\nOutput:\n$output\n";
    }
  }
  };

task "prepare",
  group => "servers",
  sub {
  my $param = shift;

  my $project     = $param->{project};
  my $application = $project->application;
  my $instance    = $application->get_deployable_instance;

  # we need to start the instance by default before deployment
  # (backward compatibility, tomcat must run)
  $param->{start_before_deploy} //= $application->need_start_before_deploy // 1;

  # hook: before_prepare_task
  for my $hook ( @{ $hooks->{before_prepare_task} } ) {
    $hook->( $project, $application, $instance, $param );
  }

  if ( $param->{stop} ) {
    $instance->stop;
  }

  if ( $param->{kill} ) {
    $instance->kill;
  }

  my $rescue = ref $param->{rescue} ? $param->{rescue}->[0] : $param->{rescue};

  if ($rescue) {
    my $context = "/";
    if ( ref $param->{rescue} ) {
      $context = $param->{rescue}->[1] || "/";
    }

    $instance->rescue( { context => $context } );
  }

# run ->start (which will check if tomcat is running, and if not, just start it)
# before the configuration of the app. At this point an old version of the application might be
# deployed and can crash tomcat if the configuration is wrong.
  if ( $param->{start_before_deploy} ) {
    $instance->start;
  }

  # if the configuration should run before the deployment
  # this is important for tomcat applications

  if ( -d "conf" && !exists $param->{configure_app} ) {
    $param->{configure_app} ||= ["fs://conf"];
  }

  if ( $param->{configure_app} && !$application->post_configuration ) {

    # hook: prepare_before_configure_app
    for my $hook ( @{ $hooks->{before_configure_app} } ) {
      $hook->( $project, $application, $instance, $param );
    }

    $param->{configure_app} = (
      ref $param->{configure_app} eq "ARRAY"
      ? $param->{configure_app}
      : [ $param->{configure_app} ]
    );
    $instance->configure_app( @{ $param->{configure_app} } );

    # hook: prepare_after_configure_app
    for my $hook ( @{ $hooks->{after_configure_app} } ) {
      $hook->( $project, $application, $instance, $param );
    }
  }

  if ( $param->{deploy_lib} ) {
    $param->{deploy_lib} = (
      ref $param->{deploy_lib} eq "ARRAY"
      ? $param->{deploy_lib}
      : [ split( /,/, $param->{deploy_lib} ) ]
    );

    # hook: prepare_before_deploy_lib
    for my $hook ( @{ $hooks->{before_deploy_lib} } ) {
      $hook->( $project, $application, $instance, $param );
    }

    $instance->deploy_lib( @{ $param->{deploy_lib} } );

    # hook: prepare_after_deploy_lib
    for my $hook ( @{ $hooks->{after_deploy_lib} } ) {
      $hook->( $project, $application, $instance, $param );
    }
  }

  if ( $param->{deploy_app} ) {
    $param->{deploy_app} = (
      ref $param->{deploy_app} eq "ARRAY"
      ? $param->{deploy_app}
      : [ $param->{deploy_app} ]
    );

    # hook: prepare_before_deploy_app
    for my $hook ( @{ $hooks->{before_deploy_app} } ) {
      $hook->( $project, $application, $instance, $param );
    }

    $instance->deploy_app( @{ $param->{deploy_app} } );

    # hook: prepare_after_deploy_app
    for my $hook ( @{ $hooks->{after_deploy_app} } ) {
      $hook->( $project, $application, $instance, $param );
    }
  }

# if the deployment should run after the deployment
# for example php applications, when the configuration is inside the extracted archive.
  if ( $param->{configure_app} && $application->post_configuration ) {
    $param->{configure_app} = (
      ref $param->{configure_app} eq "ARRAY"
      ? $param->{configure_app}
      : [ $param->{configure_app} ]
    );

    # hook: prepare_before_configure_app
    for my $hook ( @{ $hooks->{before_configure_app} } ) {
      $hook->( $project, $application, $instance, $param );
    }

    $instance->configure_app( @{ $param->{configure_app} } );

    # hook: prepare_after_configure_app
    for my $hook ( @{ $hooks->{after_configure_app} } ) {
      $hook->( $project, $application, $instance, $param );
    }
  }

  $param->{linked_dirs} ||= $project->defaults->{linked_directories};

  if ( exists $param->{linked_dirs} && $param->{linked_dirs} ) {
    $instance->create_symlinks( $param->{linked_dirs} );
  }

  if ( $param->{restart} ) {
    $instance->restart;
  }
  if ( $param->{test} && !$project->is_multi_instance ) {
    require Apptest::Test;
    my $test = Apptest::Test->new(
      project       => $project,
      expected_code => ( $param->{test}->{expected_code} || 200 )
    );
    $test->port( $project->application->get_deployable_instance()->port );
    $test->test( $param->{test} );
  }

  # hook: after_prepare_task
  for my $hook ( @{ $hooks->{after_prepare_task} } ) {
    $hook->( $project, $application, $instance, $param );
  }

  };

task "test",
  group => "servers",
  sub {
  my $param = shift;
  if ( $param->{location} && $param->{project}->is_multi_instance ) {
    require Apptest::Test;
    my $test = Apptest::Test->new(
      project       => $param->{project},
      expected_code => ( $param->{expected_code} || 200 )
    );
    $test->port(
      $param->{project}->application->get_deployable_instance()->port );
    $test->test($param);
  }
  };

task "switch",
  group => "servers",
  sub {
  my $param = shift;

  my $project = $param->{project};

  # hook: before_switch
  for my $hook ( @{ $hooks->{before_switch} } ) {
    $hook->( $project, $param );
  }

  if ( $project->is_multi_instance ) {
    my $application = $project->application;
    $application->switch;

    # hook for multi_instance_switch
    for my $hook ( @{ $hooks->{switch_multi_instance} } ) {
      $hook->($project, $param);
    }

  }
  else {

    # create active file, because init system relies on it
    my ($instance) = $project->application->get_instances;
    $instance->activate;

    # hook for single_instance_switch
    for my $hook ( @{ $hooks->{switch_single_instance} } ) {
      $hook->($project, $param);
    }
  }

  # hook: after_switch
  for my $hook ( @{ $hooks->{after_switch} } ) {
    $hook->( $project, $param );
  }

  };

task "purge_inactive",
  group => "servers",
  sub {
  my $param = shift;

  if ( $param->{project}->is_multi_instance ) {
    my $inactive = $param->{project}->application->get_inactive();
    if ( ref $inactive ) {
      Rex::Logger::info("Inactive instance found, purging...");
      $inactive->rescue;
    }
    else {
      Rex::Logger::info(
        "Project seems to be multiinstance but no inactive instance found.",
        "warn" );
    }
  }
  else {
    Rex::Logger::info("No inactive instance found. No switch needed.");
  }
  };

no warnings;
use POSIX ":sys_wait_h";

sub Rex::Fork::Task::wait {
  my ($self) = @_;
  my $rpid = waitpid( $self->{pid}, &WNOHANG );
  if ( $rpid == -1 ) { $self->{'running'} = 0; }

  if ( @Rex::Fork::Task::PROCESS_LIST
    && $Rex::Fork::Task::PROCESS_LIST[-1] != 0 )
  {
    Rex::Logger::info( "Stopping task execution.", "error" );
    Rex::Logger::debug(
"This is from Project::Tasks which is doing a full stop if something failed."
    );
    CORE::unlink("vars.db");
    CORE::unlink("vars.db.lock");
    CORE::unlink("Rexfile.lock");
    CORE::exit(1);
  }

  return $rpid;
}

my ( $major, $minor ) = split( /\./, $Rex::VERSION );
if ( $major == 1 && $minor < 4 ) {
  no warnings;

  sub Rex::Commands::do_task {
    my $task   = shift;
    my $params = shift;

    $params ||= { Rex::Args->get };

    if ( ref($task) eq "ARRAY" ) {
      for my $t ( @{$task} ) {
        Rex::TaskList->create()->get_task($t) || die "Task $t not found.";
        Rex::TaskList->run( $t, params => $params );
      }
    }
    else {
      Rex::TaskList->create()->get_task($task) || die "Task $task not found.";
      return Rex::TaskList->run( $task, params => $params );
    }
  }

  sub Rex::TaskList::run {
    my ( $class, $task_name, %option ) = @_;
    my $task_object = $class->create()->get_task($task_name);

    for my $code ( @{ $task_object->{before_task_start} } ) {
      $code->($task_object);
    }

    $class->create()->run( $task_name, %option );

    for my $code ( @{ $task_object->{after_task_finished} } ) {
      $code->($task_object);
    }
  }
}

1;
