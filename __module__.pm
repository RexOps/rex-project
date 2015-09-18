#
# 
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:
   
package Project;

use Moose;


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
      die "Can't detect project name.";
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

    my @php_out    = run "rpm -qa | grep php-fpm";
    my @tomcat_out = run "rpm -qa | grep tomcat";

    if(scalar @php_out >= 1) {
      require Application::PHP::FPM;
      return Application::PHP::FPM->new(project => $self);
    }
    elsif(scalar @tomcat_out >= 1) {
      require Application::Tomcat;
      return Application::Tomcat->new(project => $self);
    }
    else {
      confess "Can't detect type of application.";
    }
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
