# Kadalu Server Task Management

Server maintains a database table for managing Tasks. Each task will be assigned to a Storage Node and then the respective Storage nodes will pick the task and executes.

When a task is added to the table, the state of the Task is set to `Queued`. Once a Storage node picks up the Task then it sets the state to `Received`. The Node agent identifies list of Participant storage nodes for that request and calls respective nodes APIs to execute the task. For example, if the Task is `volume_create` then the Storage units needs to created in all storage nodes specified in Volume create request. Once the initiator node gets response from all participating nodes then it updates the State(`Completed` or `Failed`) back to the Server.

## Example: Volume Create

Send POST request to Kadalu Server requesting a Volume needs to be created.

```
POST <kadalu-server>/api/v1/clusters/:cluster_id/volumes
```

After validation, the request will be added to `tasks` table, and the task is assigned to first node specified in the Volume Create request. It can be assigned to `random(participating_nodes)` but there are chances of task order going out of sync. In most cases this should not be a problem since `volume_start` request should fail if `volume` entry is not in Volume's table. In any case, enhancement is required to not assign the dependent tasks to other nodes than the initiated one.

Now, Server doesn't have access to call the Node agents APIs to execute these tasks. Storage nodes can be behind the firewall or running in laptop for demo/experiments. Storage nodes where node agents are running will call the tasks API to get the list of tasks assigned to respective node.

```
GET <kadalu-server>/api/v1/tasks/:cluster_id/:node_id
```

Immediately after the task is fetched, task state will be updated as `Received`. Identify the participating nodes from the task and then make a POST request to all participating nodes.

```
task.participating_nodes.each do |node|
    POST "#{node.endpoint}/api/v1/tasks/#{task.type}"
end
```

If all the participating nodes returns success, then update task State as `Completed` else update the state as `Failed`.

If the server receives `state == Completed` then it creates a record in respective table, in this example it is `volumes` table. Now if we run `kadalu volume list` then it will show the entry. The status of the Tasks can be checked by running `kadalu task list` command.

## TODO

* Handle the Failed cases, If a task is failed because a node was down or any other recoverable error then new command can help to retrigger a failed task once the issue is resolved. If a task is failed due to an issue which can't be fixed then Rollback is required.
* Load balance the tasks - Currently every task is assigned to first participating node. In some cases this may become overhead for some nodes. This can be distributed to other nodes if a task is independent and no strict execution order required.
* Task CLI improvements - Show more meaningful information about the tasks.
* Task API improvements - Enhance the API to return the tasks which are created after a timestamp specified in the request.
