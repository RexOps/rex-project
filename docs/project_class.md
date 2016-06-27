# The Project Class

The project class is the main object to manage the application deployment. 
You can customize the object by setting the attributes on object creation. It is
also possible to subclass it and override the attributes and methods to suite 
your needs.


## Attributes


| Attribute                        | Default                                        | Description |
|----------------------------------|------------------------------------------------|-------------|
| srv_root_path                    | /srv                                           | The path where to search for application instances. |
| deploy_start_time                | `time()`                                       | The time when the deployment was started. |
| name                             | The subfolder of `$srv_root_path`              | The name of the project. |
| project_path                     | Concatenation of `$srv_root_path` and `$name`. | The path to the project. |
| application                      | Auto detect                                    | The application object to use. |
| configuration_template_variables | `Rex::Commands::connection()->server`          | Custom template variables for configuration. |
| is_multi_instance                | Auto detect                                    | Specifies if it is a multi instance application. |



## Methods

| Method                           | Return         | Arguments                       | Description |
|----------------------------------|----------------|---------------------------------|-------------|
| defaults                         | scalar | Ref   | Optional: HashRef with defaults | Set defaults for the project. |
| get_configurations               | scalar         | -                               | Return the configuration to use. Default: *conf* if directory *conf* exists. |
| deploy                           | -              | Hash                            | Run the deployment. Call the methods: *pre_check_systems*, *prepare*, *test*, *switch* and *purge_inactive*. |
| pre_check_systems                | -              | Hash                            | Call *pre_check_systems* task. |
| prepare                          | -              | Hash                            | Call *prepare* task. |
| test                             | -              | Hash                            | Call *test* task. |
| switch                           | -              | Hash                            | Call *switch* task. |
| purge_inactive                   | -              | Hash                            | Call *purge_inactive* task. |


