# env2module-differ

## Table of content

* [What's this](#what-is-this)
* [Why](#why)
* [Prerequirements](#prerequirements)
* [Usage](#usage)
* [Limitations](#limitations)
* [Questions and Feedback](#questions-and-feedback)
* [License](#license)

## What is this

This is a neat little Ruby script. It scrapes your PuppetDB API to generate a
list of all operating systems + the used Puppet modules on that OS

## Why

Many people have big environment with different operating systems and upstream
modules. Most upstream modules use
[rspec-puppet-facts](https://github.com/mcanevet/rspec-puppet-facts#rspec-puppet-facts)
for their tests. That means that all tests are executed for all operating
systems listed in a metadata.json file of a module.

We can increase test coverage and decrease the chances of silently introduced
bugs by adding the operating systems we actually use to the metadata.json.
With this project we aim to disover differences between metadata.json files
and the real world

## Prerequirements

We use a Ruby gem to connect to PuppetDB. The gem expects
`~/.puppetlabs/client-tools/puppetdb.conf`. This file is used by several
Puppet Inc tools. The content can look like this:

```json
{
  "puppetdb": {
    "server_urls": "https://mypuppetdb:8081",
    "cacert": "/home/bastelfreak/.puppetlabs/etc/puppet/ssl/certs/ca.pem",
    "cert": "/home/bastelfreak/.puppetlabs/etc/puppet/ssl/certs/bastelfreak.pem",
    "key": "/home/bastelfreak/.puppetlabs/etc/puppet/ssl/private_keys/bastelfreak.pem"
  }
}
```

Please ensure that:

* This file exists
* That the referenced certificates exist as well
* That the connection to PuppetDB works as well

We also need to install some gems:

```
bundle install --path .vendor/ --jobs "$(nproc)" --without r10k
```

If we not only want to generate a table with all modules, but also compare the
real world with the individual metadata.json files, we need to provide a path
to a directory that contains all modules.

If you use r10k, but don't have all modules locally, you can get them with:

```sh
r10k puppetfile install --moduledir './modules/' --puppetfile /path/to/Puppetfile --verbose info --color
```

You can install r10k via your system package manager or download it from the
[puppet.com](https://puppet.com) website. For convenience we also have it in
our Gemfile. If you want to install it, please do:

```
bundle install --path .vendor/ --jobs "$(nproc)" --with r10k
```

If you want to use r10k installed through bundle, use it like this:

```
bundle exec r10k puppetfile install --moduledir './modules/' --puppetfile /path/to/Puppetfile --verbose info --color
```

## Usage

To generate the full markdown table you need to execute one command!

```
bundle exec ruby main.rb
```

This will generate you the `module_os_matrix_complete.md` file.

You can get a bit of debug output if you set an environment variable named
`DEBUG`. The content of it doesn't matter.

```
DEBUG=foo bundle exec ruby main.rb
```

you need to deploy your modules to `./modules` as mentioned in the
[Prerequirements](#prerequirements) section. Once this was successful, the
script caches the PuppetDB catalogs because every PuppetDB API call is quite
expensive. You can delete the cache with:

```sh
rm ~/.cache/env2module-differ/cache.yaml
```

## Limitations

* This project currently ignores environments and always assumes `production`
* It's tested on modern Ruby 2.6 / 2.7

## Questions and Feedback

You've got questions? This project doesn't work in your environment? You want
to contribute? Reach out to bastelfreak in the #voxpupuli IRC channel on
Freenode.

## License

This project is licensed under the [AGPL v3](LICENSE).
