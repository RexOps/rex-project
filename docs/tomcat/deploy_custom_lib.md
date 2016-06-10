# Deploy custom Java libraries

Sometimes it is necessary to deploy custom java libraries into tomcats lib 
folder.

## Uploading libs from command line

```bash
$ rex Project:Tasks:rollout --deploy-lib=path/to/lib1.jar,path/to/lib2.jar
```

## Upload libs via code

If you have your own `rollout` Task and call the `Project:Tasks:rollout` from 
within your task you can just use the `deploy_lib` parameter.

```perl
task "rollout", sub {
  Project::Tasks::rollout {
    deploy_lib => ['path/to/lib1.jar', 'path/to/lib2.jar'],
  };
};
```


If you need to customize your deployment and upload the libs inside your custom
code the `Instance` object has a `deploy_lib` method you can use.

```perl
package YourCustom::Instance;

use Moose;
extends qw(Application::Tomcat::Instance);

around deploy_app => sub {
  my ($orig, $self, $war, @options) = @_;
  
  $self->deploy_lib("path/to/lib1.jar", "path/to/lib2.jar");
  
  $self->$orig($war);
};

1;
```


 

