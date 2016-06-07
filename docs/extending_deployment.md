# Extending Deployment

If you need to do more than the default and also overriding some default
variables isn't enought, you can extend the deployment with custom classes.

The code is written with Moose and so it is easy to create derived classes.

# Szenarios

## Extending configuration processing

If it is not enough to just upload some configuration files and parse them as
templates you can write your own configuration class.

## Custom application deployment

If you need to deploy an application that doesn't fit in the provided schemas,
it is also possible to write custom deployment classes.
For this you can derive from a class that fits "a little bit" to your 
application and override or extend the methods you need to enhance.

### Creating a custom application class

If you need to create a custom application class you have to register this
class in the *Project* class so that the project can detect the application.

This is done by calling the `Project->register_app_type($order, $package, $callback)`
method.
The lower `$order` is, the more likely it is to be chosen from the detection 
code.
The detection code will call the given callback to *detect* the application.

File: *lib/MyApplication/__module__.pm*

```perl
package MyApplication;

use Moose;
extends qw(Application::Tomcat);

require Rex::Command;

Project->register_app_type(1, __PACKAGE__, sub {
  my $server = Rex::Command::connection()->server;

  if($server =~ m/^myapp-frontend-\d+/) {
    # this is the server for the special app
    return 1; # true
  }

  return 0; # false, try next application
});

1;
```

You also need to create an *instance* class, because every application needs
an *application* and an *instance* class.

File: *lib/MyApplication/Instance.pm*

```perl
package MyApplication::Instance;

use Moose;
extends qw(Application::Tomcat::Instance);

use File::Basename qw(basename);
use Rex::Commands::File;

override deploy_app => sub {
  my ($self, $war) = @_;

  $war = $self->app->download($war);
  if( ! -f $war ) {
    die "File $war not found.";
  }
  
  # just upload war file, don't use manager
  file $self->instance_path . "/webapps/" . basename($war),
    owner => $self->owner,
    group => $self->group,
    mode  => "0644";
};

after restart => sub {
  my ($self) = @_;
  print "Running after deploy_app\n";
};

1;
```

You'll find a list of method modifiers for Moose here: https://metacpan.org/pod/distribution/Moose/lib/Moose/Manual/MethodModifiers.pod.

### Examples

#### Deregister an application server in a loadbalancer before deployment

If you need to deregister an application server in a loadbalancer or in a 
monitoring system before the deployment process you can write your custom
deployment class and extend the *deploy_app*, *rescue* and *restart* method
to do this.


```perl

```