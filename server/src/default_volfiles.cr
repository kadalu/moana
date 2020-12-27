CLIENT_VOLFILE = <<-YAML
---
volume:
  - name: meta-autoload
    type: meta
  - type: debug/io-stats
    name: "{{ volume.name }}"
  - type: "performance/write-behind"
    name: "{{ volume.name }}-write-behind"
  - type: "features/utime"
    name: "{{ volume.name }}-utime"
subvol:
  - type: "cluster/{{ subvol.type }}"
    name: "{{ volume.name }}-{{ subvol.type }}-{{ subvol.index }}"
brick:
  - type: "protocol/client"
    name: "{{ volume.name }}-{{ subvol.type }}-{{ subvol.index }}-client-{{ brick.index }}"
    options:
      remote-subvolume: "{{ brick.path }}"
      remote-host: "{{ brick.node }}"
YAML

BRICK_VOLFILE = <<-YAML
---
brick:
  - type: "protocol/server"
    name: "{{ volume.name }}-server"
    options:
      transport-type: tcp
      auth-path: "{{ brick.path }}"
      "auth.login.{{ brick.path }}.ssl-allow": "*"
      "auth.addr.{{ brick.path }}.allow": "*"
  - type: "debug/io-stats"
    name: "{{ brick.path }}"
  - type: "features/index"
    name: "{{ volume.name }}-index"
    options:
      xattrop-pending-watchlist: "trusted.afr.{{ volume.name }}"
      index-base: "{{ brick.path }}/.glusterfs/indices"
  - type: "features/barrier"
    name: "{{ volume.name }}-barrier"
  - type: "performance/io-threads"
    name: "{{ volume.name }}-io-threads"
  - type: "features/upcall"
    name: "{{ volume.name }}-upcall"
  - type: "features/locks"
    name: "{{ volume.name }}-locks"
  - type: "features/access-control"
    name: "{{ volume.name }}-access-control"
  - type: "features/bitrot-stub"
    name: "{{ volume.name }}-bitrot-stub"
    options:
      export: "{{ brick.path }}"
  - type: "features/changelog"
    name: "{{ volume.name }}-changelog"
    options:
      changelog-brick: "{{ brick.path }}"
      changelog-dir: "{{ brick.path }}/.glusterfs/changelogs"
  - type: "storage/posix"
    name: "{{ volume.name }}-posix"
    options:
      volume-id: "{{ volume.id }}"
      directory: "{{ brick.path }}"
YAML
