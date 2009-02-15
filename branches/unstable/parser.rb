#!/usr/bin/env ruby
require "rubygems"
require "treetop"

class CStructure < Treetop::Runtime::SyntaxNode
	def name
		return (not elements[1].elements.nil?) ? elements[1].elements[1].text_value : nil
	end
	
	def fields
		return elements[3].elements[1].elements.map { |el| el.declaration }
	end
end

class CTypeDefinition < Treetop::Runtime::SyntaxNode
	def name
		return identifier.text_value
	end
end

class CDeclaration < Treetop::Runtime::SyntaxNode
	def name
		return identifier.text_value
	end
end

class CType < Treetop::Runtime::SyntaxNode

	def signed?
		return false if type.is_a?(CStructure)
		return true unless not sign.elements.nil?
		return sign.elements[0].text_value != "unsigned"
	end
	
	def pointer?
		return (not elements[2].elements.nil?)
	end

	def type
		return elements[1] if elements[1].is_a?(CStructure)
		return elements[1].text_value
	end
end

require "c.rb"

parser = CStructParser.new
file = IO.readlines("tmp/Frameworks/CalendarUI/CDStructures.h").join("")

# Strip unwanted stuff. I do this here to redue the amount of confusing
# whitespace markers required in the PEG description and to avoid the unnecessary
# parsing of comments, which are useless in this instance
file.gsub!(/^\/\/.*$/, "")
file.gsub!(/^\/\*.*?\*\//m, "")
file.gsub!(/^#.*$/, "")
file.gsub!(/^[\t\s]*/, "")
file = file.split($/).select{|l| not l.empty?}.join($/)

# Parse and report any errors
result = parser.parse(file)
puts parser.failure_reason
puts parser.terminal_failures
exit 1 if result.nil?

result.elements.each { |e|
	puts e.elements[0].type.signed?.to_s if e.elements[0].is_a?(CTypeDefinition)
}
