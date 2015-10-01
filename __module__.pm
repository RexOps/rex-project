#
# 
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:
   
package Project;

use Moose;
use feature 'state';


use common::sense;
use Moose;
use File::Spec;

use Rex::Commands::Fs;
use Rex::Commands::Run;
require Rex::Commands;

use Data::Dumper;

use overload
  'eq' => sub { shift->is_eq(@_); },
  'ne' => sub { shift->is_ne(@_); },
  '""' => sub { shift->to_s(@_); };


state @app_types;

# static method to register app types
sub register_app_type {
  my ($class, $order, $type, $code) = @_;
  push @app_types, {
    order => $order,
    class => $type,
    code  => $code,
  };
}

has srv_root_path => (
  is => 'ro',
  default => sub {
    return "/srv";
  }
);

has name => (
  is   => 'ro',
  lazy => 1,
  default => sub {
    my ($self) = @_;

    my @entries = grep { $_ !~ m/(^\.|^lost\+found)/ 
      && is_dir(File::Spec->catdir($self->srv_root_path, $_))
      } list_files $self->srv_root_path;

    if(scalar @entries == 1) {
      return $entries[0];
    }
    else {
      die "Can't detect project name. There are multiple folders in " . $self->srv_root_path . "\nPlease remove them if not needed or specify the project name manually.\n";
    }
  },
);

has project_path => (
  is => 'ro',
  lazy => 1,
  default => sub {
    my ($self) = @_;
    return File::Spec->catdir($self->srv_root_path, $self->name);
  }
);

has has_httpd => (
  is => 'ro',
  lazy => 1,
  default => sub {
    my ($self) = @_;
    my @out = run "rpm -qa | grep httpd";
    if(scalar @out > 0) {
      return 1;
    }

    return 0;
  },
);

has application => (
  is => 'ro',
  lazy => 1,
  default => sub {
    my ($self) = @_;

    for my $app_type_c (sort { $a->{order} <=> $b->{order} } @app_types) {
      my $ret = $app_type_c->{code}->();
      if($ret) {
        return $app_type_c->{class}->new(project => $self);
      }
    }

    confess "Can't detect type of application.";
  },
);

has db_migration => (
  is => 'ro',
  lazy => 1,
  default => sub {
    my ($self) = @_;

    my @php_out    = run "rpm -qa | grep php-fpm";
    my @flyway_out = run "rpm -qa | grep flyway";

    if(scalar @php_out >= 1) {
      return "DBMigrate::Migration::PHP";
    }
    elsif(scalar @flyway_out >= 1) {
      return "DBMigrate::Migration::Flyway";
    }
    else {
      confess "Can't detect type of database migration.";
    }
  },
);

has vhost => (
  is       => 'ro',
  required => 0,
);

has configuration_template_variables => (
  is       => 'ro',
  default  => sub {
    return connection->server;
  },
);

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



1;
