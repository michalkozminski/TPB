require 'nokogiri'
require 'open-uri'
require 'sanitize'

DETAILS_STRING = {
	"Type:" => :type,
	"Files:" => :files,
	"Size:" => :size,
	"Info:" => :info,
	"Spoken language(s):" => :spoken,
	"Uploaded:" => :uploaded,
	"By:" => :by,
	"Seeders:" => :seeders,
	"Leechers:" => :leechers,
	"Comments" => :comment
}

module TableResultsParser
	private

	def parse_results(html_node)
		res = html_node.css("div.detName")
		res.map do |torrent|
			torrent_node = torrent.css("a").first
			Torrent.new(torrent_node[:href], name: torrent_node.children)
		end
	end
end


class ThePirateBay
	class << self
		attr_accessor :base_url
		def configure
			yield self
		end
		def search(keyword, categories = [])
			Search.new keyword, categories
		end

		def top(category)
			Top.new category
		end
	end
end

ThePirateBay.configure do |config|
	config.base_url = "http://thepiratebay.sx"
end

class Search
	include TableResultsParser
	def initialize(query, categories = [])
		@result_html = Nokogiri::HTML(open("#{ThePirateBay.base_url}/search/#{query}/0/99/#{categories.join(',')}")) 
	end

	def result
		parse_results(@result_html)
	end
end

class Top
	include TableResultsParser
	def initialize(category)
		@result_html = Nokogiri::HTML(open("#{ThePirateBay.base_url}/top/#{category}")) 
	end

	def result
		parse_results(@result_html)
	end
end

class Torrent
	attr_reader :href, :name, :details
	def initialize(href, data)
		@href = href
		@name = data[:name]
		@details = {}
	end

	def method_missing(method)
		@details[method]
	end

	def fetch_details
		@result_html = Nokogiri::HTML(open(URI.parse(URI.encode("https://thepiratebay.sx#{href}", "[]"))))
		@result_html.css("div#details > dl").each do |dl|
			keys = dl.children.css("dt")
			values = dl.children.css("dd")
			keys.each_with_index do |key, index|
				key = Sanitize.clean(key.to_s).strip
				value = Sanitize.clean(values[index].to_s).strip
				@details[DETAILS_STRING[key]] = value if DETAILS_STRING.has_key?(key)
			end
		end
	end
end

search = ThePirateBay.top("all")
torrent = search.result.first
torrent.fetch_details
puts torrent.size