#!/usr/bin/env ruby
require 'rest-client'
require 'json'

USAGE = "getkeys.rb takes a file which is a list of github usernames,
and creates a new authorized_keys file, suffixed with a
time stamp.  Move this over the old authorized_keys file,
when you need to add new users to our stock image.

/getkeys.rb <file>

Upon successful retrevial of keys, the file authorized_keys in this directory
will be replaced with whatever keys were pulled from github.

No idea what this will do on failure.
".freeze

if ARGV.empty? || ARGV.length > 1
  puts USAGE
  exit(1)
    end

@filename = ARGV[0].strip
@backupfile = ".authorized_keys.#{Time.now.to_i}"

@gh = 'https://api.github.com'

if FileTest.exist? @filename
  @usernames = File.readlines(@filename).collect(&:strip)
else
  puts "No such file #{@filename}"
  exit(1)
end
puts @filename

@everything = {}
@usernames.each do |username|
  puts "snagging data for #{username}"
  begin
      @githubdata_raw = RestClient.get("#{@gh}/users/#{username}/keys")
      @everything[username] = JSON.parse(RestClient.get("#{@gh}/users/#{username}/keys"))
    rescue
      puts "Issue retreving user data for #{username}."
      puts 'Does the user exist?  Please check/fix the entries in your file, and try again.'
    end
end

@keys = []

@everything.each do |k, _v|
  @keys << "##{k} ssh key[s]"
  @keys += @everything[k].collect { |i| i['key'] }.sort.uniq
end

if @everything.empty?
	puts "No keys retreived?  Something is very wrong"
	exit(1)
end
File.open("authorized_keys.#{Time.now.to_i.to_s}", 'w') { |f| f.puts @keys }
