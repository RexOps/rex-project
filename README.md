# Project

Project is the main class for application deployments. It encapsulates all settings and applications a project have.

Usually you have your own project class extending this base class.


## Architecture

```
               ----
              | DB |
             / ----
            / 
 ----------/        -------------
| Project  |-------| Application |
 ----------         -------------
                         /\
                        /  \ 
                       /    \
           -----------       -----------
          | instance1 |     | instance2 |
           -----------       -----------
                |                 |
       ---------------       ---------------
      | configuration |     | configuration |
       ---------------       ---------------
```

## Extending Project class

This class uses Moose for class construction so extending this class is easy.

```perl
package My::Project {
  use Moose;
  extends 'Project';
}
```

### Overwriting Methods

Most time you want to overwrite the attribute that holds the configuration variables and the base path for you services.

#### srv_root_path

```perl
has srv_root_path => (
  is => 'ro',
  default => sub {
    return "/srv";
  }
);
```

#### configuration_template_variables 


```perl
has configuration_template_variables => (
  is       => 'ro',
  default  => sub {
    my $my_custom_variables = {
      foo => "bar",
      baz => "bam",
    };
    return $my_custom_variables;
  },
);
```


