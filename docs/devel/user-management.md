# Users, Roles and Apps

## Users

Create user by calling the below API. This is Open API accessed by external users if the Server is hosted outside the data center.

```
POST <kadalu-server>/api/v1/users
```

or via CLI,

```
$ kadalu register <name> <email>
```

User registration will not give any access to Clusters by default. But the user can login and create new Clusters. The user who creates a Cluster will become admin for that Cluster.

## Apps

Users can't access the APIs by using email and password. Call the apps API to create an app and get a Token. Store these tokens and send them while making future API calls. Following headers are required to make a successful request.

* `X-User-ID` - Example: `X-User-ID: 4a654c67-49ad-46d0-9168-0df0e6d0c1dd`
* `Authorization` - Example: `Authorization: Bearer 88d4266fd4e6338d13b845fcf289579d209c897823b9217da3e161936f031589`

From CLI, single `login` command will take care of these steps.

```
kadalu login <email>
```

Above command calls `POST /api/v1/apps` by passing Email and password. If the user is valid then it creates an App and returns it. CLI will store the response that contains `app_id`, `user_id` and `token`.

These apps will get expired if the tokens are not accessed for a week. New login is required to create new app and get token for it.

Logout command will delete the app and the locally stored file. It is also possible to logout from other apps/sessions of the same user using the same command.

```
kadalu logout [<app-id>]
```

## Roles

This feature is required to invite other users to the Cluster or for managing perticular Volume.

Roles table is created with the following fields

* `cluster_id`
* `volume_id`
* `user_id`
* `role_name`

Possible Role names are: 

* `admin` - Create and manage Volumes and Users.
* `maintainer` - Manage Volumes.
* `viewer` - View Cluster and Volumes information, no actions possible.
* `client` - Can mount the Volume.(Or all volumes if Cluster wide role)

To see if a user is Cluster Admin:

```crystal
def cluster_admin?(user_id, cluster_id)
    result = `SELECT COUNT(*)
             FROM roles
             WHERE cluster_id = <cluster_id> AND
                   volume_id = 'all' AND
                   user_id = <user_id> AND
                   name = 'admin'`

    result > 0
end
```

Get `cluster_id` from URL parameters and `user_id` from validated Header.

To check if a user is volume viewer:

```crystal
def volume_viewer?(user_id, cluster_id, volume_id)
    result = `SELECT COUNT(*)
             FROM roles
             WHERE cluster_id = <cluster_id> AND
                   volume_id = <volume_id> AND
                   user_id = <user_id> AND
                   name IN ('admin', 'maintainer', 'viewer')`

    result > 0 || cluster_viewer?(user_id, cluster_id)
end
```


## Errors

* **401 Unauthorized** If `X-User-ID` is not in Header and the Token is invalid(No entry in the `apps` table)
* **403 Forbidden** If an logged in user trying to perform the action which is not permitted. For example, user with Cluster `viewer` role trying to create a Volume.

## TODO

* Documement Roles APIs and CLI
* List all apps CLI improvements
