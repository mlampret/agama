# Agama

This repository contains both, backend and frontend code.
```
git clone ...
```

Create config file and edit it (see section [Configuration](#configuration))
```
copy agama.conf.dist agama.conf
```

To run the app in the docker (see section [Development environment](#development-environment))
```
docker build ...
docker run ...
```

Then visit http://127.0.0.1:3000/

## Configuration

Config file is not committed to the repo and is ignored by git. You will need to create it manually e.g. `cp agama.conf.dist agama.conf` and then edit `agama.conf`.

- `db` see Dockerfile, the section where the local database is created
- `dataset_dbs` multiple dataset dbs can be specified
- `apis/google` credentials for the Google OAuth2 API, to log in using a Google account

The app/container need to be restarted to pick up any config changes.

## Development environment

Before you start developing you need to create app config file describe in the previous section.

In the development environment we are using Docker. There is a `Dockerfile` in this repo that is used to build and run the container - it contains instructions on how to do that.

Once the app is running in the container it is available at `http://127.0.0.1:3000`.

The database is available at host `127.0.0.1`, port `3006`. Please note that mysql running in the container is available at the default port 3306 but it is mapped to port 3006 on your Mac - this is to avoid interference with any other mysql instances that might be using this port.

The database is rebuilt each time the container is started. Currently any database changes are lost when container is stopped unless the container state is preserved.

No restart or rebuild is needed when changing perl code, templates, stylesheets or javascript. Morbo web server will take care of any changes in the perl code and templates and there is `Agama::Plugin::VersionDir` mojo plugin that will make static file URLs change every second, hence static files will be reloaded each time a page is loaded.

## DB Migrations

In the development environment migrations are applied on an empty db when the container is started.

In the production environment migrations are not automated, for now they need to be applied manually.

## OAuth2 login

`Mojolicious::Plugin::OAuth2` module is used to enable logging in with  GSuite accounts.

## Perl code

Initially this was meant to be a very simple app that could run mysql queries and show results as a table. It has grown more than expected but not much time was allocated to this project therefore there are no tests. Also, it seems now that it would be better to completely separate backend and frontend by implementing the API but that would require more time which didn't fit the initial idea about the simple app.

The code was developed with MVC pattern in mind:
- `Model` lib/Agama/Model directory containing all the logic
- `View` templates directory
- `Controller` lib/Agama/Controller holding page controllers

The separation between the Model and Controller layers should be strict and this way the code should be self-explanatory.

Modules form the Mojolicious package are used when possible to avoid dependency on many other Perl modules.

## Frontend

The following libraries / technologies are used on the frontend:
- [less](https://lesscss.org/) makes managing of stylesheets easier
- [ChartJS](https://www.chartjs.org/) to draw charts
- [DataTables](https://datatables.net/) to enable table data sorting
- [FontAwesome](https://fontawesome.com/) for some symbols 
- [jQuery](https://api.jquery.com/) for Javascript event handling

## Commands

There are a few commands that can be run from the command line.

To delete broken query data - queries without results and results pointing to non-existing queries:
```
script/agama queries delete_broken
```

To delete non-saved old queries:
```
script/agama queries delete_old
```

To kill long running queries - used in production to prevent issues related to queries that would run for too long:
```
script/agama queries kill_long_running
```

## Permissions

### Roles
Access is limited by using roles. Roles link users to datasets.

A user can have multiple roles assigned and each of the roles will allow them to access selected datasets.

Permission changes take effect instantly, including for logging in users.

### Administrators
Permissions can be managed in the app by administrators. Only administrators have access to the permission management.

## Datasets

Each dataset represents a mysql table (or multiple tables if JOINs are used).

To compose a query for one of the datasets there are a few tables that contain possible parameters for different parts of the query:
- `topic` defines the SELECT part of the query / selected fields
- `filter` table holds WHERE conditions
- `grouping` table holds options to generate the GROUP BY part

Once the query is run, one entry in the `query` table is created and one in the `result` table. The main part of the result is a 2-dimensional `matrix` that holds the data returned by the database.

For each query an MD5 is calculated and if such an MD5 already exists in the database we know that we are running an existing query. In that case only the result is stored to the database and it is linked to the existing query.

Topics, filters and groupings have to be added via migrations.


