# Storage Units(Bricks) Ports management

In GlusterFS, brick ports are dynamic. The ports assigned to an brick can change on next node reboot. This makes it very difficult to handle the firewall permissions. Kadalu Storage assigns the ports while creating the Volume. Once assigned the Storage units continues to use the same ports every time it starts.

**Note**: If these ports are used by an external application then Kadalu Storage server will not know about it. Make sure `49252-49452` ports are reserved for the Kadalu Storage units.

Kadalu volume info shows the details of the Ports used by the Storage units.

## Port reservations

Since Kadalu Storage server uses Task framework, List of ports are not final till the task is Completed. Because of this it is possible that two Storage units gets the same port. To avoid this, Kadalu Storage uses a technique to reserve a Port when a Task is created. These reserved ports are not allowed to be assigned for next 5 minutes. If a task completes within that 5 minutes time then that port will be recorded with the respective table. If the task fails then that port will be released after the timeout.

```crystal
def free_port(node_id)
    delete_expired_ports(node_id)
    used_ports = `SELECT port FROM bricks WHERE node_id = <node_id>`
    reserved_ports = `SELECT port FROM ports WHERE node_id = <node_id>`
    
    port = get_port_not_in(used_ports, reserved_ports).and_in_range(49252, 49452)
    
    # Reserve port in table
    reserve_port(port)
    
    port
end
```
