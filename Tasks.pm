#
# (c) FILIADATA GmbH
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:
   
package Project::Tasks;

use Rex -base;
use Rex::Transaction;
use Hash::Merge 'merge';
use File::Basename qw/dirname/;
use File::Spec;
use Data::Dumper;

require Project;

my $defaults = {
  context => "/",
};

my $hooks = {};

sub defaults {
  my $_def = shift;
  $defaults = merge( $defaults, $_def );
}

sub on {
  my ($hook, $code) = @_;
  push @{ $hooks->{$hook} }, $code;
}

task "rollout", sub {
  my $params = shift;
  
  my %deploy_hash = ();
  
  if(exists $params->{app}) {
    $deploy_hash{deploy_app} = [
      $params->{app},
      ( $params->{context} ? $params->{context} : $defaults->{context} )
    ];
  }

  my @conf_arr;

  if(exists $params->{configuration}) {
    push @conf_arr, $params->{configuration};
  }

  if(exists $params->{"configuration-directory"}) {
    push @conf_arr, $params->{"configuration-directory"};
  }
  else {
    push @conf_arr, $params->{context} ? $params->{context} : "app";
  }

  $deploy_hash{configure_app} = [ @conf_arr ];
  
  if(exists $params->{rescue}) {
    $deploy_hash{rescue} = [
      $params->{rescue},
      ( $params->{context} ? $params->{context} : $defaults->{context} )
    ];
  }

  if(exists $params->{stop}) {
    $deploy_hash{stop} = $params->{stop};
  }

  if(exists $params->{restart}) {
    $deploy_hash{restart} = $params->{restart};
  }

  if(exists $params->{"deploy-lib"}) {
    $deploy_hash{deploy_lib} = $params->{"deploy-lib"};
  }

  if(exists $params->{test}) {
    $deploy_hash{test} = {
      location => $params->{test},
    };
  }
  
  my %project_hash = ();
  if(exists $params->{vhost}) {
    $project_hash{vhost} = $params->{vhost};
  }
  
  if(exists $defaults->{srv_root_path}) {
    $project_hash{srv_root_path} = $defaults->{srv_root_path};
  }

  if(exists $defaults->{name}) {
    $project_hash{name} = $defaults->{name};
  }

  if(exists $defaults->{project_path}) {
    $project_hash{project_path} = $defaults->{project_path};
  }

  if(exists $defaults->{configuration_template_variables}) {
    $project_hash{configuration_template_variables} = $defaults->{configuration_template_variables};
  }

  if(exists $params->{version}) {
    $defaults->{deploy_version} = $params->{version};
  }

  my $project = Project->new(%project_hash);
  $project->defaults($defaults);

  transaction {
    $project->deploy( %deploy_hash );
    say "done.";
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

  # we need to start the instance by default before deployment
  # (backward compatibility, tomcat must run)
  $param->{start_before_deploy} //= 1;

  my $project     = $param->{project};
  my $application = $project->application;
  my $instance    = $application->get_deployable_instance;

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
  
  if(-d "conf" && ! exists $param->{configure_app}) {
    $param->{configure_app} ||= [ "fs://conf" ];
  }
  
  if ( $param->{configure_app} && !$application->post_configuration ) {
    # hook: prepare_before_configure_app
    for my $hook (@{ $hooks->{prepare_before_configure_app} }) {
      $hook->($project, $param, $application, $instance);
    }

    $param->{configure_app} = (
      ref $param->{configure_app} eq "ARRAY"
      ? $param->{configure_app}
      : [ $param->{configure_app} ]
    );
    $instance->configure_app( @{ $param->{configure_app} } );

    # hook: prepare_after_configure_app
    for my $hook (@{ $hooks->{prepare_after_configure_app} }) {
      $hook->($project, $param, $application, $instance);
    }
  }

  if ( $param->{deploy_lib} ) {
    $param->{deploy_lib} = (
      ref $param->{deploy_lib} eq "ARRAY"
      ? $param->{deploy_lib}
      : [ split(/,/, $param->{deploy_lib}) ]
    );
    # hook: prepare_before_deploy_lib
    for my $hook (@{ $hooks->{prepare_before_deploy_lib} }) {
      $hook->($project, $param, $application, $instance);
    }

    $instance->deploy_lib( @{ $param->{deploy_lib} } );

    # hook: prepare_after_deploy_lib
    for my $hook (@{ $hooks->{prepare_after_deploy_lib} }) {
      $hook->($project, $param, $application, $instance);
    }
  }

  if ( $param->{deploy_app} ) {
    $param->{deploy_app} = (
      ref $param->{deploy_app} eq "ARRAY"
      ? $param->{deploy_app}
      : [ $param->{deploy_app} ]
    );

    # hook: prepare_before_deploy_app
    for my $hook (@{ $hooks->{prepare_before_deploy_app} }) {
      $hook->($project, $param, $application, $instance);
    }

    $instance->deploy_app( @{ $param->{deploy_app} } );

    # hook: prepare_after_deploy_app
    for my $hook (@{ $hooks->{prepare_after_deploy_app} }) {
      $hook->($project, $param, $application, $instance);
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
    for my $hook (@{ $hooks->{prepare_before_configure_app} }) {
      $hook->($project, $param, $application, $instance);
    }

    $instance->configure_app( @{ $param->{configure_app} } );

    # hook: prepare_after_configure_app
    for my $hook (@{ $hooks->{prepare_after_configure_app} }) {
      $hook->($project, $param, $application, $instance);
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
    $test->port( $param->{project}->application->get_deployable_instance()->port );
    $test->test( $param );
  }
  };

task "switch",
  group => "servers",
  sub {
  my $param = shift;

  my $project = $param->{project};

  if ( $project->is_multi_instance ) {
    my $application = $project->application;
    $application->switch;
    
    # hook for multi_instance_switch
    for my $hook (@{ $hooks->{switch_multi_instance} }) {
      $hook->($project);
    }

  }
  else {

    # create active file, because init system relies on it
    my ($instance) = $project->application->get_instances;
    $instance->activate;

    # hook for single_instance_switch
    for my $hook (@{ $hooks->{switch_single_instance} }) {
      $hook->($project);
    }
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
    Rex::Logger::info( "No inactive instance found.", "warn" );
  }
  };


1;