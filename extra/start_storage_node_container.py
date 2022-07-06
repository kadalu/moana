from argparse import ArgumentParser
import subprocess
import sys


def execute(cmd):
    with subprocess.Popen(cmd, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, universal_newlines=True) as process:
        out, err = process.communicate()
        return process.returncode, out, err


def get_args(default_hostname):
    parser = ArgumentParser()
    parser.add_argument("-w", "--workdir", help="Working directory", required=True)
    parser.add_argument("storages", nargs="*", help="Storage Directories")
    parser.add_argument("--hostname", default=default_hostname, help=f"Hostname (Default: {default_hostname})")
    return parser.parse_args()


def main():
    ret, out, err = execute(["hostname"])
    if ret != 0:
        print("Failed to get hostname")
        print(err)
        sys.exit(1)

    default_hostname = out.strip()
    args = get_args(default_hostname)

    storage_vols = []
    for storage in args.storages:
        storage_vols += ["-v", f"{storage}:{storage}"]

    if len(storage_vols) == 0:
        print("[WARNING] No Storage Volumes are exposed to the Storage container.")

    cmd = [
        "docker", "run", "-d",
        "--network", "host",
        "-v", f"{args.workdir}/workdir:/var/lib/kadalu",
        "-v", f"{args.workdir}/config:/root/.kadalu"
    ] + storage_vols + \
    [
        "-v", "/sys/fs/cgroup/:/sys/fs/cgroup:ro",
        "--privileged",
        "--name", f"kadalu-{args.hostname}",
        "--hostname", args.hostname,
        "kadalu/storage-node:latest"
    ]
    print("\nExecuting the following command:")
    print(" ".join(cmd))
    print()

    ret, out, err = execute(cmd)
    if ret != 0:
        print("Failed to start the container")
        print(err)
        sys.exit(1)

    print(f"Started the Storage container. Run `sudo docker exec -it kadalu-{args.hostname} /bin/bash` to login to the Storage node")


if __name__ == "__main__":
    main()
