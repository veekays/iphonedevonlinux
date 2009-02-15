#!/usr/bin/env ruby
require "find"
require "ftools"

if ARGV.length != 2 then
	puts "Usage: class-dump.rb <frameworks folder> <includes folder>"
	exit 1
end

# Find all header import references
imports=[]
headers=[]
Find.find(ARGV[0]) { |file|
	if file =~ /\.h$/ then
		$stderr.puts "Checking #{file}..."
		File.open(file).each { |line|
			imports << /^#import "(.*)"$/.match(line)[1] if line =~ /^#import ".*"$/
			headers << file
		}
	end
}
imports.uniq!
headers.uniq!

# Try to locate the headers in the includes
replacements=[]
imports.each { |import|
	$stderr.printf "Trying to find #{import}..."
	begin
	Find.find(ARGV[1]) { |file|
		if File.basename(file) == import then
			replacements << [ import, file.sub(ARGV[1], "") ]
			raise
		end
	}
	rescue
		$stderr.puts "Found it!"
		next
	end
	$stderr.puts "Didn't find it."
}

# Replace relative entries with the located library files
headers.each { |file|
	$stderr.printf "Fixing #{File.basename(file)}..."
	File.copy(file, "#{file}.fixed") # FIXME: This is just while I'm testing the code, remove
	replacements.each { |replacement|
		contents = IO.readlines("#{file}.fixed").join("") #FIXME: Fix file name
		contents.gsub!("#import \"#{replacement[0]}\"", "#import <#{replacement[1]}>")
		File.open("#{file}.fixed", 'w') { |f| f.write(contents) } # FIXME: Fix file name
	}
	$stderr.puts "done."
}
