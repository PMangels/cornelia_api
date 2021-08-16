# API for project cornelia
This is the api providing access to the [Project Cornelia](https://www.projectcornelia.be) database.
## How to run
Below two ways to run the application will be covered. Running the application using Podman is recommended, since any dependencies are already installed.
### Podman
This section assumes that you have access to a Linux server of VM, with [Podman](https://podman.io) installed. (If not, have a look at the [instalation guide](https://podman.io/getting-started/installation).)
#### Building or loading the Podman images
##### Building
To run the API, you must first build the images.  
To build the api image you move to the api folder:  
`cd api`  
Then you build the api image, which depends on the docker.io/library/ruby:2.7.1 image:  
`podman build --tag cornelia-api:latest .`  
Move to the mysql folder:  
`cd ../mysql`  
Next you build the mysql image, which depends on the docker.io/library/mysql:5.6 image:  
`podman build --tag mysql:5.6c .`

##### Loading
Alternatively, you can save images you've build and load the images into Podman on a different machine.  
`podman save -o ./podman-image-api.tar cornelia-api`  
`podman save -o ./podman-image-mysql.tar mysql:5.6c`  
`podman load --input podman-image-api.tar`  
`podman load --input podman-image-mysql.tar`
#### Run the API
Now that the images are available you can start to run the api in a pod. In the example you are exposing the api on port 80, but if needed this can be changed to any other port.  
`podman run --name cornelia-api -p 80:9292 --pod new:cornelia-pod -d localhost/cornelia-api`  
#### Run the MySQL database
Once the api is up and running, you can run the mysql database in the same pod. Replace password with a safe password for your database. The name `mysql-cornelia` should be the same as the host in the `api/server.rb` file.  
`podman run --name mysql-cornelia --pod cornelia-pod -e MYSQL_ROOT_PASSWORD=password -d mysql:5.6c`  
Now that the mysql database is running, you have to import the right data as follows:  
`podman exec -it mysql-cornelia mysql -u root -p`  
This will ask for the root password, you have provided before and then give you a mysql terminal.  
`CREATE DATABASE www_cornelia2;`  
`USE www_cornelia2;`  
The user that is currently being used by the api (see the top of the `api/server.rb` file for these details) should be added to the database.  
`GRANT SELECT ON www_cornelia2.* TO "cornelia_api"@"%" IDENTIFIED BY "zC4%08U%Lm7y&0TP";`  
Now we need to import the data from the sql file and add the view `view_place`.  
`SOURCE /mysql/www_cornelia2.sql;`  
`CREATE VIEW view_place AS select www_cornelia2.place.id AS id,www_cornelia2.country.name AS country,www_cornelia2.city.name AS city,www_cornelia2.parish.name AS parish,www_cornelia2.street.name AS street,www_cornelia2.house.name AS house,concat_ws(', ',www_cornelia2.country.name,www_cornelia2.city.name,www_cornelia2.parish.name,www_cornelia2.street.name,www_cornelia2.house.name) AS place from (((((www_cornelia2.place left join www_cornelia2.country on((www_cornelia2.place.country_id = www_cornelia2.country.id))) left join www_cornelia2.city on((www_cornelia2.place.city_id = www_cornelia2.city.id))) left join www_cornelia2.parish on((www_cornelia2.place.parish_id = www_cornelia2.parish.id))) left join www_cornelia2.street on((www_cornelia2.place.street_id = www_cornelia2.street.id))) left join www_cornelia2.house on((www_cornelia2.place.house_id = www_cornelia2.house.id)));`  
Now we have imported all the data, we can quit the MySQL terminal:  
`QUIT;`
### Natively
If you want to run the code on your own machine, especially useful for fast testing during development, you can follow the following subsection for instructions.  
#### Run the MySQL database
For this guide a running MySQL database is assumed. We start by creating the database  
`CREATE DATABASE www_cornelia2;`  
`USE www_cornelia2;`  
The user that is currently being used by the api (see the top of the `api/server.rb` file for these details) should be added to the database.  
`GRANT SELECT ON www_cornelia2.* TO "cornelia_api"@"%" IDENTIFIED BY "zC4%08U%Lm7y&0TP";`  
Now we need to import the data from the sql file and add the view `view_place`.  
`SOURCE ./mysql/www_cornelia2.sql;`  
`CREATE VIEW view_place AS select www_cornelia2.place.id AS id,www_cornelia2.country.name AS country,www_cornelia2.city.name AS city,www_cornelia2.parish.name AS parish,www_cornelia2.street.name AS street,www_cornelia2.house.name AS house,concat_ws(', ',www_cornelia2.country.name,www_cornelia2.city.name,www_cornelia2.parish.name,www_cornelia2.street.name,www_cornelia2.house.name) AS place from (((((www_cornelia2.place left join www_cornelia2.country on((www_cornelia2.place.country_id = www_cornelia2.country.id))) left join www_cornelia2.city on((www_cornelia2.place.city_id = www_cornelia2.city.id))) left join www_cornelia2.parish on((www_cornelia2.place.parish_id = www_cornelia2.parish.id))) left join www_cornelia2.street on((www_cornelia2.place.street_id = www_cornelia2.street.id))) left join www_cornelia2.house on((www_cornelia2.place.house_id = www_cornelia2.house.id)));`  
Now we have imported all the data, we can quit the MySQL terminal:  
`QUIT;`
#### Run the API
For this guide a working [Ruby](https://www.ruby-lang.org/en/) is assumed. To find information on installing Ruby, click [here](https://www.ruby-lang.org/en/downloads/).  
Some gems should also be installed (sinatra, mysql2 etc.). See `api/Gemfile` for more information on this. Mysql2 might require a MySQL or MariaDB client. These dependencies are the main advantage of the Podman method. Running `bundle install` inside the `api` folder might install the needed gems.  
We will now assume that the necessary gems are installed.  
Running the server should be as simple as running the following command inside the `api` folder, assuming the right gems are installed and the credentials and host inside the `api/server.rb` file (at the top of the file) point to a working MySQL server with the correct database installed, see previous sections.  
`ruby rackup -o 0.0.0.0 -p 9292 config.ru`  
It might be necessary to specify `ruby` or `rackup` e.g. `/usr/bin/ruby /usr/bin/rackup -o 0.0.0.0 -p 9292 config.ru`. The location of these binaries can be found on a Linux machine using the `which` command.   


## Using the API
The use of the API, is done via HTTP requests. Any information needed for the use of the API, should be found in the documentation. This documentation is found on the html page that is hosted by the server on `host/documentation`, where host can be localhost if it is running on your localhost.  
