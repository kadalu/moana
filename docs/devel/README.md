# Developer Documentation

## Code Organization

* **server** Kadalu Storage Server, This Service can be hosted externally to manage multiple Clusters. The server will not have access to the Storage nodes directly. Instead, Storage nodes pulls required information from the server and updates the Status.
* **node** Kadalu Storage node agent. This service needs to be deployed in all the Storage nodes. This service is responsible for getting the list of tasks and execute them. Also update the state of Node and other processes back to the Kadalu Storage Server.
* **client** Crystal language bindings for Server and Node agent APIs.
* **types** Common Type definitions that will be used by Server, Client and CLI.
* **cli** CLI to interact with the Server and Node APIs using the `client` package.
* **volgen** Volfile generation library. Server will use this library to generate required Volfiles(Client, Brick, etc) using the YAML Templates.

## Topics

* [User, Roles and Apps](./user-management.md)
* [Task Management](./task-management.md)

