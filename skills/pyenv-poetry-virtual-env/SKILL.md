---
name: pyenv-poetry-virtual-env
description: use when you initialize python virtual environments, also when using poetry or pyenv
---

# Working with virtual environments

## Detect path to needed for virtual environment python version

Usually project team specifies which version of python is used by project.
path might be provided in environment variable PROJECT_BASE_PYTHON_PATH, or in project info files,known to you.

If not possible, but you know python version from project docs, check installed python versions via command

```bash
 pyenv versions --bare | grep -E '^[0-9]+(\.[0-9]+)*$'
```

having found python version, like for VERSION=3.9.15, path to python will be `$(pyenv root)/versions/3.9.15/bin/python`


## Working with python versions

There are two approaches.

### Poetry controlled virtual environment

1. when you are asked to create virtual environment managed by poetry with specific python version, you need to provide path to the python executable with
poetry env use <path to python>. If not specified, system python will be used, which is not optimal.

Use "Detect path" section to get path to the python version to use, once you have

validate `python --version` on this path to validate, that you've selected proper version and path

After that use command
`poetry env use <PROJECT_BASE_PYTHON_PATH>` to create new virtual environment based on custom project version.

### pyenv controlled virtual environment

When you are asked to create virtual environment, controlled by pyenv:

Step 1. Detect python version, PYVER check if pyenv versions lists this version

Step 2: Choose a Python version, check "Detect path" section,

Step 3: Choose a virtual environment name ENVNAME

Provide a meaningful environment name.

Recommended pattern: <project-name>-py<version>

Example: api-service-py3.11

The name must be unique within pyenv.

Step 4: Create and activate the virtual environment

Create a new pyenv virtual environment using:

pyenv virtualenv "$PYVER" "$ENVNAME"
pyenv local "$ENVNAME"

This creates a .python-version file in the project root.

From now on, entering this directory automatically activates the environment.

Step 5: Upgrade core tooling

Upgrade pip inside the newly created virtual environment.

Ensure the environment is fully ready for dependency installation.

Step 6: Decide how to manage dependencies
Option A: Use Poetry (local, pyenv-managed)

Decide whether to install Poetry inside the virtual environment.

If installed:

Configure Poetry to not create its own virtualenv.

This ensures Poetry uses the pyenv environment.

Use this command pattern to install dependencies:

poetry install --no-root (executed via pyenv)

Option B, recommended: Use global Poetry (already installed globally)

If Poetry already exists on the system:

Configure it locally to avoid virtualenv creation.

Use:

poetry install --no-root

Poetry will respect the pyenv environment.

