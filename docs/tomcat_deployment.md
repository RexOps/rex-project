# Tomcat Deployment

In this documentation you will learn how to setup a basic tomcat depoyment.

## Requirements

For this tutorial you need a system where you can run *rex* and a system where 
you have already installed a tomcat server. You also need to install tomcat
manager.

Also you need your application as a *.war archive.

This archive will be uploaded to the tomcat server and deployed with the help
of the tomcat manager.

The deployment expects that tomcat is running with the help of tanuki wrapper.
This is because rex will monitor the logfile *logs/wrapper.log* to get notified
when the tomcat start was successful.

Rex also reads the *conf/tomcat-users.xml* file to get the username and
password for tomcat manager.

The port of your tomcat installation is also autodetected. For this to work
you need to configure the port in the file *conf/wrapper.conf.d/java.additional.conf*
or into *conf/wrapper.conf*. It looks for a line `-Dtomcat.http.port=`.

## Specifications

* Rex-Box: mngt-rex-01
* Webserver: www-01
* $project_name: rex-demo

## Creating the deployment project

First you need to create a rex project on the Rex Box. You can do this with the
following commands:

```bash
mkdir rex-demo
cd rex-demo
touch Rexfile
touch meta.yml
touch server.ini
```

As of rex 1.5 you can also run this command:

```bash
rexify rex-demo --template=tomcat-deployment
```

### The Rexfile

The first thing you need to edit is the Rexfile. Here you just need to load
the *Project::Tasks* module which will create a default *rollout* task for you.

```perl
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:
# vim: set ft=perl:

use Rex -feature => ['1.4'];
use Project::Tasks;

1;
```

### The meta.yml

In this file you have to configure the dependencies your Rexfile (and all the
included modules) have.

So for this project you can just copy&paste the next box into this file.

```yaml
Name: rex-demo
Description: My first static deployment
License: internal use
Require:
  Project:
    git: https://github.com/RexOps/rex-project.git
    branch: 201606_02
  Application:
    git: https://github.com/RexOps/rex-application.git
    branch: 201606_02
```

### The server.ini file

In the server.ini file you can define server groups. You need to create a
group named *servers*. The deployment code will use this group to connect to
the right servers.

```ini
[servers]
www-01 user=root password=box pass_auth
```

If you have key authentication you can use:

```ini
[servers]
www-01 user=root private_key=/path/to/private.key public_key=/path/to/public.key
```

And if you can't login with root and need to use sudo you can do this with this:

```ini
[servers]
www-01 user=deploy private_key=/path/to/private.key public_key=/path/to/public.key sudo=1 sudo_password=if-you-need-one
```

## Running the deployment

### Default directory structure

The default directory structure for a deployment is like this:

```
+--+ /srv/$project_name/tomcat/$instance
   |
   +--+ conf/
      +--+ wrapper.conf
         + server.xml
         + tomcat-users.xml
         + ...
   +--+ lib/
   +--+ webapps/
      +--+ manager/
   +--+ logs/
      +--+ wrapper.log
   +--+ active           # this file is create by rex to flag the active instance
```

* $project_name is a name you can choose freely
* $instance is also a name to allow tomcat multi instance deployment. This name
  should contain a number. For example: *i01* or *tc01*.

To run the deployment you just need to call the *Project:Tasks:rollout* tasks.

```bash
rex Project:Tasks:rollout --app=myapp.war
```

If you need to deploy to a special context, you can use the *context* parameter.

```bash
rex Project:Tasks:rollout --app=myapp.war --context=/probe
```

#### Deployment Parameters

* --context=/path - Deployment Context
* --restart - Will restart Tomcat after deployment.
* --rescue - Will stop Tomcat, cleanup work directory and start Tomcat before deploying the new application.
* --deploy-lib=lib1,lib2,... - Will upload the content of path into the *lib* directory of your Tomcat instance. 
* --configuration=fs://path - Will upload the content of path into the *conf/app* folder.
* --configuration-directory=dir - Will upload the configuration into *conf/<dir>*.
* --test=/url - Will query this url and check for a status code of 200 before running the switch.

### Customizing deployment

Like the static deployment, you can customize the behaviour of the tomcat 
deployment.

Possible parameters:

* tomcat_port - The port where the tomcat http connector is listening.
* tomcat_username - The user under which tomcat is running.
* tomcat_groupname - The group of the user under which tomcat is running.
* manager_username - The username for tomcat manager.
* manager_password - The password for tomcat manager.
* manager_path - The path to tomcat manager. Default: *manager*
* service_name - The service name to start/stop/restart tomcat.

An example Rexfile where tomcat is deployed to /mytc

```perl
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:
# vim: set ft=perl:

use Rex -feature => ['1.4', 'tty'];
use Project::Tasks;

Project::Tasks::defaults {
  deploy_path => "/mytc",
  service_name => "tomcat-i03",
};

1;
```
