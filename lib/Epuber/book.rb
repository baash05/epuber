require_relative 'dsl/object'
require_relative 'book/vendor/contributor'

module Epuber

	class StandardError < ::StandardError; end

	class Book < DSLObject

		def initialize
			super
			yield self if block_given?
			__finish_parsing
			__validate
		end


		private

		def __finish_parsing
			if self.author
				self.author = Contributor.create(self.author, 'aut')
			end
		end

		def __validate
			unless self.author.kind_of? Contributor
				throw StandardError, 'author|authors is not defined'
			end
		end

		public


		#---------------------------------------------------------------------------------------------------------------

		# @return [String] title of book
		#
		attribute :title,
				  :required => true

		# @return [String] subtitle of book
		#
		attribute :subtitle

		# @return [Array<Contributor>] authors of book
		#
		attribute :authors,
				  :types       => [Contributor],
				  :container   => Hash,
				  :required    => true,
				  :singularize => true

		# @return [String] publisher name
		#
		attribute :publisher


		#---------------------------------------------------------------------------------------------------------------
		define_properties_methods
	end
end
