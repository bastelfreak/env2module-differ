#

require 'puppetdb'

# establish a connection to PuppetDB
# only works if you have ~/.puppetlabs/client-tools/puppetdb.conf
client = PuppetDB::Client.new()

# get all nodes
response = client.request('facts', [:'=', 'name', 'operatingsystem' ])
nodes = response.data
puts "We've got #{nodes.count} systems in our environment"

# sort all nodes by OS
# it would be helpful if we could sort by major OS version as well
data = Hash.new
nodes.each {|node| data[node['value']] ? data[node['value']] << node['certname'] : data[node['value']] = [node['certname']]}
used_modules = Hash.new
data.each {|os|
  used_modules[os] = Array.new
  os.each {|server|
    # get one catalog
    catalog = client.request('catalogs', [:"=", "certname", server])
    # get all modules from the catalog
    # We get all resources, if it's from the correct type we split the string to get only topscope namespaces (a module, not their individual classes)
    # afterwards purge nil elements in the array with compact
    # catalog.data.first['resources']['data'].map{|data| data['title'].split('::')[0] if data['type'] == 'Class'}.compact
    # and since we run on Ruby 2.7 we can use the awesome filter_map method!
    modules = catalog.data.first['resources']['data'].filter_map{|data| data['title'].split('::')[0] if data['type'] == 'Class'}

    # that long line is equivalent to:
    # catalog.data.first['resources']['data'].select {|data| data['type'] == 'Class'}.map{|data| data['title'].split('::')[0]}
    # if you care about all those different combinations of map and filter and whatever, check this out:
    # https://stackoverflow.com/questions/3371518/in-ruby-is-there-an-array-method-that-combines-select-and-map

    used_modules[os] << modules
  }
}
blargh = nodes.map {|node|
  fqdn = node['certname']
  os = node['value']
  catalog = client.request('catalogs', [:"=", "certname", fqdn])
  modules = catalog.data.first['resources']['data'].filter_map{|data| data['title'].split('::')[0].downcase if data['type'] == 'Class'}.uniq
  {os => modules}
}

blargh[0]
