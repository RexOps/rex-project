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