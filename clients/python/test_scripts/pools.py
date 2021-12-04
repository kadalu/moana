import sys

from kadalu import StorageManager

url = sys.argv[1]
cmd = sys.argv[2]

client = StorageManager(url)

if cmd == "create":
    pool_name = sys.argv[3]
    print(client.create_pool(pool_name))
elif cmd == "list":
    print(client.list_pools())
