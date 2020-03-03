# frozen_string_literal: true

##
# Written by Tim 'bastelfreak' Meusel
# Licensed as AGPL-3
##

require 'puppetdb'
require 'markdown-tables'
require 'yaml'

# ensure we've a persistent cache directory
homedir = Dir.home
cachedir = "#{homedir}/.cache/env2module-differ"
Dir.mkdir cachedir unless File.exist? cachedir

# establish a connection to PuppetDB
# only works if you have ~/.puppetlabs/client-tools/puppetdb.conf
client = PuppetDB::Client.new

# get all nodes + operatingsystem and operatingsystemmajrelease fact
response = client.request('facts', [:'=', 'name', 'operatingsystem'])
nodes_with_operatingsystem = response.data
response = client.request('facts', [:'=', 'name', 'operatingsystemmajrelease'])
nodes_with_operatingsystemmajrelease = response.data

puts "We've got #{nodes_with_operatingsystem.count} systems in our environment"

# merge FQDN + facts into one Hash
nodes_with_os_and_version = {}
nodes_with_operatingsystem.each do |server|
  os = server['value']
  # get the operating system major version for the current server
  os_array = nodes_with_operatingsystemmajrelease.select { |node| node['certname'] == server['certname'] }
  os_version = os_array.first['value']
  # naming schema is OS-Majorversion
  # Except for rolling releases Like Arch and Gentoo
  rolling = %w[Archlinux Gentoo]
  nodes_with_os_and_version[server['certname']] = if rolling.include?(server['value'])
                                                    os
                                                  else
                                                    "#{os}-#{os_version}"
                                                  end
end

os_array = nodes_with_os_and_version.values.uniq.sort
os_strings = os_array.join(', ')
os_array_amount = os_array.count
puts "We've the following Operating Systems: #{os_strings} (#{os_array_amount})"

final_data = {}

nodes_with_os_and_version.each do |server|
  # get the common name
  certname = server[0]
  # get the os / release string
  os = server[1]
  # get a catalog for this common name
  catalog = client.request('catalogs', [:"=", 'certname', certname])

  # get all classes
  resources = catalog.data.first['resources']['data']
  # requires ruby2.7
  # modules = resources.filter_map{|data| data['title'].split('::')[0] if data['type'] == 'Class'}

  # Get all resources that are classes
  classes = resources.filter { |data| data['type'] == 'Class' }
  # Get all top level modules, ignore subclasses
  modules = classes.map { |data| data['title'].split('::')[0].downcase }.uniq

  # remove classes that aren't modules
  modules -= %w[main settings]
  puts "processed: #{certname} with #{modules.count} modules on #{os}"
  puts modules.join(', ')

  # ensure that our final array contains a hash for that OS-Version combination
  final_data[os] = [] unless final_data[os]
  final_data[os] = (final_data[os] + modules).uniq.sort
end

# plot a markdown table to a file
labels = final_data.keys
data = final_data.map { |os| os[1] }
table = MarkdownTables.make_table(labels, data)

File.open('module_os_matrix.md', 'w') { |file| file.write(table) }

## create a more readable table
all_modules = data.flatten.uniq.sort
labels = ['Modules \ OS'] + labels
new_data = []
# first column with _all_ modules
new_data << all_modules
# now create one array per os-specific column
data.each do |module_array|
  new_column = []
  all_modules.each do |modul|
    new_column << if module_array.include?(modul)
                    modul
                  else
                    ''
                  end
  end
  new_data << new_column
end

## for our master table
new_data = []
data.each do |module_array|
  new_column = []
  all_modules.each do |modul|
    new_column << if module_array.include?(modul)
                    modul
                  else
                    ''
                  end
  end
  new_data << new_column
end

new_table = MarkdownTables.make_table(labels, new_data)
File.open('module_os_matrix_big.md', 'w') { |file| file.write(new_table) }

# $1 is the directory for the cache file
# $2 is the data we want to store
def write_cache(cachedir, data)
  Dir.mkdir cachedir unless File.exist? cachedir
  File.write("#{cachedir}/cache.yaml", data.to_yaml)
end

# if the cache doesn't exist, we query the PuppetDB
def load_cache(cachedir)
  YAML.safe_load(File.open("#{cachedir}/cache.yaml"))
end

# $1 is the PuppetDB client
def all_nodes_with_os(client)
  response = client.request('facts', [:'=', 'name', 'operatingsystem'])
  response.data
end

# $1 is the PuppetDB client
def all_nodes_with_os_major_version(client)
  response = client.request('facts', [:'=', 'name', 'operatingsystemmajrelease'])
  response.data
end

# $1 is an array of hashes with certname + OS
# $2 is an array of hashes with certname + major OS version
def merge_os_and_version_hashes(operatingsystems, operatingsystemmajreleases)
  nodes_with_os_and_version = {}
  operatingsystems.each do |server|
    os = server['value']
    # get the operating system major version for the current server
    # `find` returns an hash. We only want the `value` key
    os_version = operatingsystemmajreleases.find { |node| node['certname'] == server['certname'] }['value']
    # naming schema is `OS`-`Majorversion`
    # Except for rolling releases Like Arch and Gentoo
    rolling = %w[Archlinux Gentoo]
    nodes_with_os_and_version[server['certname']] = if rolling.include?(server['value'])
                                                      os
                                                    else
                                                      "#{os}-#{os_version}"
                                                    end
  end
  nodes_with_os_and_version
end

# $1 is the PuppetDB client
def nodes_with_os_and_version(client)
  operatingsystems = all_nodes_with_os(client)
  operatingsystemmajreleases = all_nodes_with_os_major_version(client)
  merge_os_and_version_hashes(operatingsystems, operatingsystemmajreleases)
end

# $1 is the common name from a valid agent certificate
# $2 is the PuppetDB client object
def all_used_modules_on_one_server(certname, client)
  # get a catalog for this common name
  catalog = client.request('catalogs', [:"=", 'certname', certname])

  # get all classes
  resources = catalog.data.first['resources']['data']
  # requires ruby2.7
  # modules = resources.filter_map{|data| data['title'].split('::')[0] if data['type'] == 'Class'}

  # Get all resources that are classes
  classes = resources.filter { |data| data['type'] == 'Class' }
  # Get all top level modules, ignore subclasses
  modules = classes.map { |data| data['title'].split('::')[0].downcase }.uniq.sort

  # remove classes that aren't modules
  modules - %w[main settings]
end

# $1 is the return value from nodes_with_os_and_version()
# $2 is the PuppetDB client
def all_used_modules_from_puppetdb(nodes_with_os_and_version, client)
  final_data = {}
  nodes_with_os_and_version.each do |certname, os|
    puts certname
    modules = all_used_modules_on_one_server(certname, client)
    puts "processed: #{certname} with #{modules.count} modules on #{os}"
    puts modules.join(', ')

    # ensure that our final array contains a hash for that OS-Version combination
    final_data[os] = [] unless final_data[os]
    final_data[os] = (final_data[os] + modules)
  end
  final_data
end

# $1 is the path to the cache file
# $2 is the PuppetDB client object
def all_used_modules(cachedir, client)
  begin
    # load local YAML cache if it exists
    os_module_hash = load_cache(cachedir)
  rescue Errno::ENOENT
    # Query PuppetDB because we don't have any cache
    # Update our Cache and return the value afterwards
    response = nodes_with_os_and_version(client)
    os_module_hash = all_used_modules_from_puppetdb(response, client)
    write_cache(cachedir, os_module_hash)
  end
  os_module_hash
end

def modules_metadata(path)
  metadatas = {}
  Dir.glob("#{path}/*/metadata.json") do |metadata|
    # get the name of the module based on the path
    modulename = File.basename(File.split(metadata)[0])
    begin
      input = JSON.parse(File.read(metadata))
      metadatas[modulename] = input
    rescue JSON::ParserError
      next
    end
  end
  metadatas
end

# This currently doesn't parse OS dependencies correctly if they don't have an array
# That's sometimes the case for rolling release distros like Arch and Fedora
def generate_os_version_names(metadatas)
  metadatas.map do |_module, metadata|
    os_version_names = if metadata['operatingsystem_support']
                         data = metadata['operatingsystem_support'].map do |os|
                           if os['operatingsystemrelease'].nil?
                             if %w[Gentoo Archlinux].include?(os['operatingsystem'])
                               [os['operatingsystem']]
                             else
                               []
                             end
                           else
                             os['operatingsystemrelease'].map { |rel| "#{os['operatingsystem']}-#{rel}" }
                           end
                         end
                         data.flatten.sort!
                       else
                         []
                       end
    metadata['os_version_names'] = os_version_names
  end
  metadatas
end

# We wan't to have links to the repos in the markdown table
def get_all_modules_with_links(all_modules, metadatas)
  all_modules.map do |modul|
    name = metadatas[modul]['name'].nil? ? name : metadatas[modul]['name']
    if metadatas[modul]['project_page'].nil?
      name
    else
      "[#{name}](#{metadatas[modul]['project_page']})"
    end
  end
end

# $1 = A Hash. Each key is an OS, Each value an array of used modules on that OS
# $2 = an array with all used modules (NOT all modules in the environment)
# $3 = all metadatas in a hash, extended
def render_master_markdown(os_module_hash, all_modules, metadatas)
  new_data = []
  new_data << get_all_modules_with_links(all_modules, metadatas)
  os_module_hash.each do |os, moduls_on_os|
    new_column = []
    all_modules.each do |modul_in_env|
      new_column << if moduls_on_os.include?(modul_in_env)
                      if metadatas[modul_in_env]['os_version_names'].include?(os)
                        'used'
                      else
                        'incomplete'
                      end
                    else
                      'not used'
                    end
    end
    new_data << new_column
  end
  new_data
end
