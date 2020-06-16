
module Xenqu
   module Models

      class RestError < ::StandardError; end
      Environment = Struct.new( :logger, :base_xenqu_api, :oauth_token, :record_for_testing )

      class << self
         attr_accessor :environment
         def config
            self.environment ||= Environment.new
         end

         def configure
            yield( config )

            config.base_xenqu_api ||= 'https://xenqu.com/api'

            RestClient.log = config.logger || STDOUT

            RestClient.add_before_execution_proc do |req, params|
               #puts self.inspect, params[:method].to_s.upcase, params[:url].gsub( /(.*)\/api(.*)/, '\1\2' )
               #need to sign without /api proxy map
               #that's not confusing or anything...
               if !params[:url].index( config.base_xenqu_api ).nil?
                  header = ::SimpleOAuth::Header.new( params[:method].to_s.upcase, params[:url], nil, config.oauth_token.merge({ :ignore_extra_keys => true }) )
                  req['Authorization'] = header.to_s
               end
            end
         end
      end

      module Utils

         @rec_incr = 0
         @last_call_time = Time.now.to_f

         def self.process_url_params( url, params )

            if !params.empty?
              query_string = params.collect { |k, v| "#{k.to_s}=#{CGI::escape(v.to_s)}" }.join('&')
              url + "?#{query_string}"
            else
              url
            end
         end

         def self.call( method, baseurl, params={} )

            begin

               if ( sleep_time = Time.now.to_f - @last_call_time ) < 0.25
                  sleep( 0.25 - sleep_time )
               end

               data = ''
               if method == :get
                  url = process_url_params( baseurl, params )
                  resp = RestClient.send( method, url )
               elsif method == :delete
                  url = process_url_params( baseurl, params )
                  opts = { :content_type => :json, :accept => :json }
                  resp = RestClient.send( method, url, opts )
               else
                  url = baseurl
                  data = params.to_json
                  opts = { :content_type => :json, :accept => :json }
                  resp = RestClient.send( method, url, data, opts )
               end

               if Xenqu::Models.config.record_for_testing
                  File.open( './rest-record-'+@rec_incr.to_s+'.txt', 'w') {|f| f.write( method.to_s+"\n"+url+"\n"+data+"\n"+resp ) }
                  @rec_incr += 1
               end

               # This should be happening in RestClient, but
               # doesn't seem to be working as of 2.0.0rc2
               resp.force_encoding( Encoding.find( 'utf-8' ) )

               return JSON( resp )

            rescue => e

               if e.respond_to?( :response )
                  raise e.message.to_s + ' | ' + e.response.to_s
               else
                  raise e.message.to_s
               end
            ensure
               @last_call_time = Time.now.to_f
            end

         end

      end

      class Base

         attr_reader :urlRoot, :values

         class << self
            attr_reader :id_attribute

            def fetch( params = {} )
               self.new.fetch( params )
            end

            def []( data )
               self.new( data )
            end
         end

         def initialize( data = {}, options = {} )
            @values = data.clone
            parse
         end

         def fetched?
            !!@fetched_once
         end

         def fetch( params = {} )
            @fetched_once = true

            data = Utils.call( :get, url, params )

            if data.is_a?( Array )
               data.map{ |d| self.class.new( d ) }
            else
               @values = data
               parse
            end
         end

         def save
            method = is_new? ? :post : :put

            @values = Utils.call( method, url, @values )
         end

         def delete( params = {} )
            data = Utils.call( :delete, url, params )
         end

         private

         def parse
            # Map to class instance variables
            @values
         end

         def is_new?
            !!self.values[id_attribute].nil?
         end

         def url
            base = base_xenqu_api + urlRoot

            if !is_new?
               base += '/'+self.values[id_attribute].to_s
            end

            base
         end

         def id_attribute
            self.class.id_attribute
         end

         protected

         def self.base_xenqu_api
            Xenqu::Models.config.base_xenqu_api
         end

         def base_xenqu_api
            Xenqu::Models.config.base_xenqu_api
         end

      end

      class FileChunker

         attr_reader :url, :chunkLimit, :chunkedField

         def initialize( options )

            opts = options || {}

            @url = opts[:url] || ''
            @chunkLimit = opts[:chunkLimit] || 500000
            @chunkedField = opts[:chunkedField] || ''

            if opts[:data]
               prepare( opts[:data] )
            end
         end

         def prepare( data )

            content = data[chunkedField]
            totalSize = content.length
            totalChunks = ( totalSize.to_f / chunkLimit.to_f ).floor

            data.delete( chunkedField )

            @buffer = (0..totalChunks).map do | c |

               cS = c * chunkLimit
               cE = ( c + 1 ) * chunkLimit - 1
               chunkData = content[cS..cE]

               {
                  'chunkData'      => chunkData,
                  'chunkSeq'       => c,
                  'chunkStart'     => cS,
                  'chunkEnd'       => cE,
                  'chunkSize'      => chunkData.length,
                  'chunkLimit'     => chunkLimit,
                  'totalSize'      => totalSize,
                  'totalChunks'    => totalChunks+1
               }

            end

         end

         def send

            fileHandle = nil

            @buffer.each do | chunk |

               if fileHandle
                  chunk['fileHandle'] = fileHandle
               end

               resp = Utils.call( :post, base_xenqu_api + '/' + url, chunk )

               fileHandle = resp['fileHandle'];

            end

            fileHandle

         end

         private

         def base_xenqu_api
            Xenqu::Models.config.base_xenqu_api
         end

      end

   end
end
