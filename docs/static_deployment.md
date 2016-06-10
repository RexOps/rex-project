# Static Deployment

In this documentation you will learn how to setup a basic static file 
deployment.

## Requirements

For this tutorial you need a system where you can run *rex* and a system where 
you have already installed a webserver. For example the apache webserver.

Also you need some kind of a package (a zip or tar.gz archive) where the files
are located which you want to deploy to your webserver.

This package will be uploaded to the webserver and extracted into a deployment 
directory. After this, the document root of your webserver will be symlinked
to this deployment directory.

On the webserver you need the following directory structure. You can also
override these defaults by yourself, but this tutorial will follow the defaults.

* /srv/$project_name/www/$vhost_name/deploy

Your apache webserver must configure the *DocumentRoot* to 

* /srv/$project_name/www/$vhost_name/app

## Specifications

* Rex-Box: mngt-rex-01
* Webserver: www-01
* $project_name: rex-demo
* $vhost_name: myhost.de

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
rexify rex-demo --template=static-deployment
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
+--+ /srv/$project_name/www/$vhost_name
   |
   +--+ deploy
      +--+ 130422553
         + 130422570 
   +--+ htdocs         --> Symlink to: deploy/130422570
```

To run the deployment you just need to call the *Project:Tasks:rollout* tasks.

```bash
rex Project:Tasks:rollout --app=my-app.zip --vhost=myhost.de
```

### Customizing deployment path and document root

If you don't have the directory structure mentioned above, you can also 
customize the deployment location.

For this, just open your Rexfile and override project defaults.

```perl
use Rex -feature => ['1.4'];
use Project::Tasks;

Project::Tasks::defaults {
  deploy_path        => "/var/www/deploy",
  document_root_path => "/var/www/htdocs",
};

1;
```

This will upload the archive into a subdirectory of */var/www/deploy* and then
link */var/www/htdocs* to this folder.

### Configuration files

If you need to upload one or more configuration files you can do this, by
creating a directory *conf* and place your files there.

Textfiles are treated as a template, so it is possible to use embedded perl
inside these files.

The default is to upload those files into the *conf/app* subdirectory of the
deployment folder.

To customize this, you can set the defaults value *configuration_path*.

### Data directories

If you have one or more directories that needs to get shared between
deployments, you can use the defaults option *linked_directories* to manage
them.

```perl
use Rex -feature => ['1.4'];
use Project::Tasks;

Project::Tasks::defaults {
  linked_directories => [
    "data",
  ],
};
```

This will create a directory *shared* under the path you defined with 
*deploy_path*. It also will copy the content of the *data* directory into this
shared folder.

If you want to use a non-default shared path you can set it with *data_path*.

## Getting the deployment artifact

There are multiple ways how you can retrieve the deployment artifact. In the 
examples we imply that the artifact is somewhere stored on the local filesystem.
But it is also possible to download the artifact from a remote webserver.

For this you just need to specify the url:

```bash
rex Project:Tasks:rollout --app=http://dl.yourdomain.tld/my-app.zip --vhost=myhost.de
```

### Authentication

If you need to authenticate to your download server you can define the user and
password.

```perl
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:
# vim: set ft=perl:

use Rex -feature => ['1.4'];
use Project::Tasks;

Project::Tasks::defaults {
  http_user => "the-user",
  http_password => "the-password",
};

1;
```


