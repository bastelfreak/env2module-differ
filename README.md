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
r10k puppetfile install --moduledir './modules/' --puppetfile /path/to/Puppetfile
```

You can install r10k via your system package manager or download it from the
[puppet.com](https://puppet.com) website. For convenience we also have it in
our Gemfile. If you want to install it, please do:

```
bundle install --path .vendor/ --jobs "$(nproc)" --with r10k
```

If you want to use r10k installed through bundle, use it like this:

```
bundle exec r10k puppetfile install --moduledir './modules/' --puppetfile /path/to/Puppetfile
```

## Usage

To generate the full markdown table you need to populate the methods from the
main.rb into your env and afterwards execute this:

```ruby
metadatas = modules_metadata('/home/bastelfreak/env2module-differ/modules')
metadatas_enhanced = generate_os_version_names(metadatas)
homedir = Dir.home
cachedir = "#{homedir}/.cache/env2module-differ"
client = PuppetDB::Client.new
os_module_hash = all_used_modules(cachedir, client)
labels = os_module_hash.keys
labels = ['Modules \ OS'] + labels
all_modules = os_module_hash.map { |os| os[1] }.flatten.sort.uniq
data = render_master_markdown(os_module_hash, all_modules, metadatas_enhanced)
table = MarkdownTables.make_table(labels, data)
File.open('module_os_matrix_complete.md', 'w') { |file| file.write(table) }
```

This will generate you the `module_os_matrix_complete.md` file.

## Limitations

* This project currently ignores environments and always assumes `production`
* It's tested on modern Ruby 2.6 / 2.7

## Questions and Feedback

You've got questions? This project doesn't work in your environment? You want
to contribute? Reach out to bastelfreak in the #voxpupuli IRC channel on
Freenode.

## License

This project is licensed under the [AGPL v3](LICENSE).
