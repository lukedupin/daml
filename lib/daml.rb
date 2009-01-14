#DAML - Dupin YAML File
#This file loads YAMLS in a usable way, no one likes Hashs!
#Note this code is slow, and should only be used for testing
#If you need something faster, make the klass ahead of time and just fill it!

require 'yaml'

class Daml
		#Return a value from the systems config directory
	def self.get_config( config )
		file = "#{File.dirname(__FILE__)}/../config/#{config.to_s}.yml"
		env = ((defined? RAILS_ENV)? RAILS_ENV : :development).to_sym
		return self.load_daml(file, env )
	end

		#Load a test fixture, very helpful
	def self.load_test_daml(klass, block = nil)
		file = "#{File.dirname(__FILE__)}/../test/fixtures/#{klass.to_s}.yml"
		return self.load_daml( file, block )
	end

		#Load any yaml
	def self.load_daml( dir, block = nil )
		yaml = YAML::load(File.open(dir))

			#start filling my daml file
		daml = Hash.new
		yaml.each { |key, value| daml[key.to_sym] = self.fill_daml( value ) }

			#Finally, if block was given, junk everything but that one instance
		return (block)? daml[block]: daml
	end

		#Create a daml file from a hash
	def self.load_hash( hash, limit = Hash.new, only = nil )
		ary = Array.new
		hash.each do |k, v| 
			if (only.nil? and limit[k].nil?) or (only and only[k])
				ary.push( self.fill_daml( { :key => k, :value => v } )) 
			end
		end

		return ary	
	end

		#Load by Array of arrays
	def self.load_array( fields, data )
		d_index = false
		if !data.is_a? Array
			data = [data] 
			d_index = true
		end
		fields = [fields] if !fields.is_a? Array

			#Create a list of all my data
		ary = Array.new
		data.each do |d|
			item = (d.is_a? Array)? d: [d]

				#Create a hash containing all my data
			hash = Hash.new
			((item.size >= fields.size)? item.size: fields.size).times do |i|
				hash[fields[i]] = item[i]
			end

				#Make that hash into a daml file
			ary.push( self.fill_daml( hash ) )
		end

			#Return my data
		return (d_index)? nil: ary if ary.size == 0
		return (d_index)? ary[0]: ary
	end

		#Recursive method for reading yaml
	private
	def self.fill_daml( yaml )

			#Create a new class that is can add accessors
		klass = Class.new
		klass.class_eval do
			attr_reader :accessors

			def initialize
				@accessors = Array.new
			end

			def add_accessor(acs)
				eval("class << self; attr_accessor :#{acs}; end")
				@accessors.push(acs.to_sym)
			end

			#Generate a yaml hash from the daml file, using symbols instead of strings
			def dump(except = Hash.new, only = nil, reg = nil, invert_reg = false, &e)
				h = Hash.new
				@accessors.each do |a| 
					if (only.nil? and except[a].nil?) or	#User is excluding symbols
							(!only.nil? and only[a]) or				#Only allow these symbolrs
							(reg and (a.to_s =~ reg)? !invert_reg: invert_reg)	#Regex Match

							#Attempt to call the users block
						if e
							ary = e.call( a, self.send(a) )
							h[ary[0]] = ary[1]
						#No block given, conduct normal operation
						else
							h[a] = self.send(a) 
						end
					end
				end
				return h
			end

			#This will return an array of daml files that have a uniform addressing
			#method of the value of key and value.  Useful when dumping to select's
			def uniform_daml( key, value, except = Hash.new, 
												only = nil, reg = nil, invert_reg = false, &e )
					#One line to create a uniform aray of daml files... Thats hot!
				Daml.load_array( [key.to_sym, value.to_sym], 
													self.dump( except, only, reg, invert_reg, &e).to_a )
			end
		end
		daml = klass.new

			#First we start looking what is inside this thing
		yaml.each do |key, value|

				#First we add an accessor of this key name
			daml.add_accessor(key)

				#Now figure out what we are looking at here
			if value.kind_of? Hash
				eval("daml.#{key} = fill_daml(value)")
			else
				eval("daml.#{key} = value")
			end
		end
		return daml
	end
end
