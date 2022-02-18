require "moana_volgen"

SHD_VOLFILE = <<-YAML
---
pool:
  - type: debug/io-stats
    name: "glustershd"
distribute_group:
  - type: "cluster/{{ distribute_group.type }}"
    name: "{{ volume.name }}-{{ distribute_group.type }}-{{ distribute_group.index }}"
    options:
      data-self-heal: on
      iam-self-heal-daemon: true
      metadata-self-heal: on
      self-heal-daemon: on
      choose-local: true
      ensure-durability: on
      data-change-log: on
      entry-self-heal: on
      afr-pending-xattr: "{{ distribute_group.afr-pending-xattr }}"
storage_unit:
  - type: "protocol/client"
    name: "{{ volume.name }}-{{ distribute_group.type }}-{{ distribute_group.index }}-client-{{ storage_unit.index }}"
    options:
      remote-subvolume: "{{ storage_unit.path }}"
      remote-host: "{{ storage_unit.node }}"
      remote-port: "{{ storage_unit.port }}"
YAML

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
  - type: "cluster/distribute"
    name: "{{ volume.name }}-distribute"
    include_when: #{CONDITION_MORE_THAN_ONE_DISTRIBUTE_GROUP}
distribute_group:
  - type: "cluster/{{ distribute_group.type }}"
    name: "{{ volume.name }}-{{ distribute_group.type }}-{{ distribute_group.index }}"
    options:
      afr-pending-xattr: "{{ distribute_group.afr-pending-xattr }}"
storage_unit:
  - type: "protocol/client"
    name: "{{ volume.name }}-{{ distribute_group.type }}-{{ distribute_group.index }}-client-{{ storage_unit.index }}"
    options:
      remote-subvolume: "{{ storage_unit.path }}"
      remote-host: "{{ storage_unit.node }}"
      remote-port: "{{ storage_unit.port }}"
YAML

STORAGE_UNIT_VOLFILE = <<-YAML
---
storage_unit:
  - type: "protocol/server"
    name: "{{ volume.name }}-server"
    options:
      transport-type: tcp
      auth-path: "{{ storage_unit.path }}"
      "auth.login.{{ storage_unit.path }}.ssl-allow": "*"
      "auth.addr.{{ storage_unit.path }}.allow": "*"
  - type: "debug/io-stats"
    name: "{{ storage_unit.path }}"
  - type: "features/index"
    name: "{{ volume.name }}-index"
    options:
      xattrop-pending-watchlist: "trusted.afr.{{ volume.name }}"
      index-base: "{{ storage_unit.path }}/.glusterfs/indices"
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
  - type: "features/changelog"
    name: "{{ volume.name }}-changelog"
    options:
      changelog-brick: "{{ storage_unit.path }}"
      changelog-dir: "{{ storage_unit.path }}/.glusterfs/changelogs"
  - type: "storage/posix"
    name: "{{ volume.name }}-posix"
    options:
      volume-id: "{{ volume.id }}"
      directory: "{{ storage_unit.path }}"
YAML
