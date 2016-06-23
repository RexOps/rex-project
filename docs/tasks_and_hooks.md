# Tasks and Hooks

The Project module comes with some default tasks which should satisfy the most
use cases. If you need to modify the behaviour of these tasks you can use hooks
to do this.

Hooks can be used to modify the behaviour of default tasks without overriding
the the task.

## Available default Tasks

### rollout

The rollout task is the default task you call to start the deployment. This
task assembles all parameters for the deployment.

#### Parameters

| Parameter               | Default | Description |
|-------------------------|:-------:|-------------|
| app                     | -       | The artifact that should be deployed. |
| configuration           | -       | Which directory should be used to upload the configuration. |
| configuration-directory | app     | Upload destination for the configuration. |
| rescue                  | -       | Cleanup application server before deployment. This will stop the server, cleanup the context and restart it again. |
| stop                    | -       | Stop application server before deployment. |
| restart                 | -       | Restart application server after deployment |
| start-before-deploy     | -       | Ensure that application server is started before deployment. For example if the deployment is done with an application running inside the container (tomcat manager application). |
| purge-inactive          | -       | Cleanup the inactive instance after deployment. |
| deploy-lib              | -       | Deploy additional libraries to the library folder of the application instance. |
| test                    | -       | Run a http test against the application server. Return Code must be *200* if it is another status it will stop the deployment. |
| vhost                   | -       | If there is a virtual host (standard or php deployment) you have to set this. |
| version                 | -       | Which version of the software should be deployed. This is for standard and php deployment to generate the deployment directory. |


#### Hooks

There is one hook in this task which can be run before the *deploy*. This hook
is executed within the global transaction.

##### before_task_deploy

This hook will run before the *deploy* method of the given project class. It
will run inside the global deployment transaction.

```perl
Project::Tasks:on(
  before_task_deploy => sub {
    my ( $project, $params ) = @_;
    # do things
  },
);
```



### pre_check_systems

This task runs on all servers before the deployment start. It will upload all 
files from *tests.d* into */var/cache/rex/test* and execute them. If one of 
these scripts has a exit code of `>= 1` the deployment will stop.

### prepare

The *prepare* task will do the heavy lifting. It will upload configuration,
upload libraries, deploy the application and restart the application server.

#### Parameters

| Parameter               | Default | Description |
|-------------------------|:-------:|-------------|
| project                 | -       | The project object. |
| start_before_deploy     | TRUE    | Ensure that application server is started before deployment. For example if the deployment is done with an application running inside the container (tomcat manager application). Will also ask the *application* class if it needs it. |
| stop                    | -       | Stop application server before deployment. |
| kill                    | -       | Kill application server before deployment. |
| rescue                  | -       | Cleanup application server before deployment. This will stop the server, cleanup the context and restart it again. |
| configure_app           | -       | Use the given directory or configuration class to configure the instance.  |
| deploy_lib              | -       | Deploy given libraries into the *lib* folder of the instance. Can be a comma separated string or an array reference. |
| deploy_app              | -       | The application artifact that should be deployed. |
| linked_dirs             | -       | Directories that should be linked to a special persistant data directory. For example to store session information or uploads. |
| restart                 | -       | Restart application server after deployment |
| test                    | -       | Run a http test against the application server. Return Code must be *200* if it is another status it will stop the deployment. |

#### Hooks

You can modify the behavior of the *prepare* tasks with hooks.

##### before_prepare_task

This code will run before all the other actions the *prepare* task will do.

```perl
Project::Tasks::on(
  before_prepare_task => sub {
    my ( $project, $application, $instance, $param ) = @_;
  },
);
```

##### before_configure_app

This will run before the *prepare* task will upload the configuration.

```perl
Project::Tasks::on(
  before_configure_app => sub {
    my ( $project, $application, $instance, $param ) = @_;
  },
);
```

##### after_configure_app

This will run after the *prepare* task uploaded the configuration.

```perl
Project::Tasks::on(
  after_configure_app => sub {
    my ( $project, $application, $instance, $param ) = @_;
  },
);
```

##### before_deploy_lib

This will run before the *prepare* task will upload additional libraries.

```perl
Project::Tasks::on(
  before_deploy_lib => sub {
    my ( $project, $application, $instance, $param ) = @_;
  },
);
```

##### after_deploy_lib

This will run after the *prepare* task has uploaded additional libraries.

```perl
Project::Tasks::on(
  after_deploy_lib => sub {
    my ( $project, $application, $instance, $param ) = @_;
  },
);
```

##### before_deploy_app

This will run before the *prepare* task will deploy the application.

```perl
Project::Tasks::on(
  before_deploy_app => sub {
    my ( $project, $application, $instance, $param ) = @_;
  },
);
```

##### after_deploy_app

This will run after the *prepare* task has deployed the application.

```perl
Project::Tasks::on(
  after_deploy_app => sub {
    my ( $project, $application, $instance, $param ) = @_;
  },
);
```

##### after_prepare_task

This hook will run at the end of the *prepare* task.

```perl
Project::Tasks::on(
  after_prepare_task => sub {
    my ( $project, $application, $instance, $param ) = @_;
  },
);
```


### test

Run the tests across all servers. If a test failed on one server the deployment
will stop.

#### Parameters

| Parameter               | Default | Description                            |
|-------------------------|:-------:|----------------------------------------|
| project                 | -       | The project object.                    |
| location                | -       | The URL that should be queried.        |
| expected_code           | 200     | The HTTP status code that is expected. |


### switch

This task will run after the tests where successful to enable the instance that
was deployed in the *prepare* task. For static deployment this will update the 
symlink which points from the document root of the webserver to the deployed 
version.

#### Parameters

| Parameter               | Default | Description         |
|-------------------------|:-------:|---------------------|
| project                 | -       | The project object. |


#### Hooks

##### before_switch

This hook will run before the instance switch of the application.

```perl
Project::Tasks::on(
  before_switch => sub {
    my ( $project, $param ) = @_;
  },
);
```

##### switch_multi_instance

This hook will run after the *switch* method call of the detected application.
It will only run for applications which has a multi instance deployment.

```perl
Project::Tasks::on(
  switch_multi_instance => sub {
    my ( $project, $param ) = @_;
  },
);
```

##### switch_single_instance

This hook will run after the *activate* method call of the detected application.
It will only run for applications which has a single instance deployment.

```perl
Project::Tasks::on(
  switch_single_instance => sub {
    my ( $project, $param ) = @_;
  },
);
```

##### after_switch

This hook will run at the end of the *switch* task.

```perl
Project::Tasks::on(
  after_switch => sub {
    my ( $project, $param ) = @_;
  },
);
```

### purge_inactive

This task will run if *purge-inactive* was provided to the rollout task. This
will run at the very end and cleanup the now inactive application instance.
This will only run if multiple instances of the application was found.

#### Parameters

| Parameter               | Default | Description         |
|-------------------------|:-------:|---------------------|
| project                 | -       | The project object. |

