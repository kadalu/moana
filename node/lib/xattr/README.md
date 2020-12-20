# XAttr

[![Build Status](https://travis-ci.org/ettomatic/xattr.svg?branch=master)](https://travis-ci.org/ettomatic/xattr)

Crystal bindings to [XATTR](https://man7.org/linux/man-pages/man7/xattr.7.html).

This library allows to manage extended file attributes (XATTR). Filesystem support implemented for Linux and MacOS.

Extended attributes are name:value pairs associated permanently with files and directories and can be used to add semantic metadata, see [guidelines](https://www.freedesktop.org/wiki/CommonExtendedAttributes/).

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     xattr:
       github: ettomatic/xattr
   ```

2. Run `shards install`

## Usage

```crystal
require "xattr"

xattr = XAttr.new("./myfile.txt")
xattr["tags"] = "mytag1,mytag2"
xattr["tags"]
# => "mytag1,mytag2"

xattr.keys
# => ["tags"]

xattr.to_h
# => { "tags" => "mytag1,mytag2" }

xattr.remove("tags")
xattr.keys
# => []

xattr["tags"]
# => nil
```

## Contributing

1. Fork it (<https://github.com/ettomatic/xattr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Ettore Berardi](https://github.com/ettomatic) - creator and maintainer
