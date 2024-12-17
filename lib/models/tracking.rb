module Xenqu
   module Models

      class Item < Base
         @id_attribute = 'item_id'

         def initialize( data, options = {} )
            @scope = options[:scope] || :owner
            super( data, options )
         end

         def urlRoot
            if @scope == :group
               @urlRoot = '/tracking/groups/'+self.values['tracking_group_id'].to_s+'/list/items'
            else #@scope == :owner
               @urlRoot = '/tracking/items'
            end
         end
      end


      class Queue_Template < Base

         @id_attribute = '_id'

         def urlRoot
            @urlRoot = '/tracking/groups/'+self.values['tracking_group_id'].to_s+'/queue_templates'
         end

         def search( params )

            Utils.call( :get, base_xenqu_api + urlRoot, params )
         end

      end

      class Tracking_Group < Base

         @id_attribute = 'tracking_group_id'

         def urlRoot
            @urlRoot = '/tracking/groups'
         end

         def members
            Tracking_Member[ 'tracking_group_id' => @values['tracking_group_id'] ]
         end

         def queues
            Tracking_Queue[ 'tracking_group_id' => @values['tracking_group_id'] ]
         end

         def libraries
            Tracking_Library[ 'tracking_group_id' => @values['tracking_group_id'] ]
         end

         def items
            Item.new({ 'tracking_group_id' => @values['tracking_group_id'] }, { :scope => :group } )
         end

         def queue_templates
            Queue_Template[ 'tracking_group_id' => @values['tracking_group_id'] ]
         end

         def generate_login( contact, opts = {} )
            call_url = '/tracking/groups/'+self.values['tracking_group_id'].to_s+'/user/create'

            resp = Utils.call( :post, base_xenqu_api + call_url, opts.merge( contact ) )

            resp
         end

         def recover_login( contact, opts = {} )
            call_url = '/tracking/groups/'+self.values['tracking_group_id'].to_s+'/user/reset'

            resp = Utils.call( :post, base_xenqu_api + call_url, opts.merge( contact ) )

            resp            
         end
         
         def get_callbacks
            call_url = '/tracking/groups/'+self.values['tracking_group_id'].to_s+'/callback'

            resp = Utils.call( :get, base_xenqu_api + call_url )

            resp
         end

         def set_callback( url, ctype, tid=nil )
            call_url = '/tracking/groups/'+self.values['tracking_group_id'].to_s+'/callback'

            resp = Utils.call( :post, base_xenqu_api + call_url, { :callback_url => url, :type => ctype, :item_id => tid } )

            resp
         end

         def unset_callback( url, ctype, tid=nil )
            call_url = '/tracking/groups/'+self.values['tracking_group_id'].to_s+'/callback'

            resp = Utils.call( :delete, base_xenqu_api + call_url, { :callback_url => url, :type => ctype, :item_id => tid } )

            resp
         end
      end

      class Tracking_Actor < Base

         @id_attribute = 'contact_id'

         def urlRoot
            @urlRoot = '/tracking/groups/' + self.values['tracking_group_id'].to_s + '/actors'
         end

         def send_text( params )
            call_url = '/tracking/groups/' + self.values['tracking_group_id'].to_s + '/send_text/' + self.values['contact_id'].to_s 

            resp = Utils.call( :post, base_xenqu_api + call_url, params )

            resp
         end

         def send_email( params )
            template_id = params[:template_id] || '0000000'
            
            call_url = '/tracking/groups/' + self.values['tracking_group_id'].to_s + '/email_templates/' + template_id.to_s + '/send/' + self.values['contact_id'].to_s

            resp = Utils.call( :post, base_xenqu_api + call_url, params )

            resp 
         end

         def contact_logs( params={} )
            
            qs = ''
            if params.keys.length > 0
                qs = '?' + params.to_param
            end
            
            call_url = '/tracking/groups/' + self.values['tracking_group_id'].to_s + '/contact_log/' + self.values['contact_id'].to_s + qs

            resp = Utils.call( :get, base_xenqu_api + call_url )

            resp
         end

         def apply_rules
            call_url = urlRoot + '/' + self.values['contact_id'].to_s + '/apply_rules'

            resp = Utils.call( :post, base_xenqu_api + call_url, {} )

            resp
         end

         def set_record_callback( url, section )
            call_url = '/tracking/groups/'+self.values['tracking_group_id'].to_s+
                         '/actors/' + self.values['contact_id'].to_s+ 
                         + '/' + section.to_s + '/callback'

            resp = Utils.call( :put, base_xenqu_api + call_url, { :callback_url => url } )

            resp
         end

         def unset_record_callback( url, section )
            call_url = '/tracking/groups/'+self.values['tracking_group_id'].to_s+
                         '/actors/' + self.values['contact_id'].to_s+
                         + '/' + section.to_s + '/callback'

            resp = Utils.call( :delete, base_xenqu_api + call_url, { :callback_url => url } )

            resp
         end

         def get_mappings
            call_url = urlRoot + '/' + self.values['contact_id'].to_s + '/mappings'

            resp = Utils.call( :get, base_xenqu_api + call_url )

            resp['data']
         end
         
         def set_mappings( data )
            call_url = urlRoot + '/' + self.values['contact_id'].to_s + '/mappings'

            resp = Utils.call( :post, base_xenqu_api + call_url, { :data => data } )

            resp['data']
         end

         def exec_lyon( code, section = nil )
            call_url = '/tracking/groups/' + self.values['tracking_group_id'].to_s + '/execute_lyon/' + self.values['contact_id'].to_s
            Utils.call( :post, base_xenqu_api + call_url, { :code => code, :section => section.to_s } )
         end         
      end

      class Tracking_Member < Base

         @id_attribute = 'user_id'

         def initialize( data, options = {} )
            @options = options
            super( data, options )
         end

         def urlRoot
            @urlRoot = '/tracking/groups/'+self.values['tracking_group_id'].to_s+'/members'
         end
         
         def member_of
            call_url = '/tracking/groups/'+self.values['user_id'].to_s+'/groups'
            Utils.call( :get, base_xenqu_api + call_url )
         end
      end

      class Tracking_Queue < Base

         @id_attribute = 'tracking_queue_id'

         def urlRoot
            @urlRoot = '/tracking/groups/'+self.values['tracking_group_id'].to_s+'/queues'
         end

         def find_open_item( item )
            find_item( item, [:open] )
         end

         def find_item( item, stats )
            flt = stats.map{ |s| s.to_s }
            self.values['items'].detect{ |i| i['item_id'] == item['item_id'] && flt.include?( i['status'] ) }
         end

         def found?
            self.values.has_key?( 'tracking_group_id' )
         end
      end

      class Tracking_Library < Base

         @id_attribute = 'tracking_queue_id'

         def urlRoot
            @urlRoot = '/tracking/groups/'+self.values['tracking_group_id'].to_s+'/libraries'
         end

         def find( params )
            call_url = urlRoot + '/select'

            Utils.call( :post, base_xenqu_api + call_url, params )
         end
      end

      class Tracking_Item < Base

         @id_attribute = 'tracking_id'

         def initialize( data, options = {} )
            @options = options
            super( data, options )
         end

         def urlRoot
            if @options[:as_actor]
               @urlRoot = '/tracking/user/items'
            elsif @options[:scope] == 'activity'
               @urlRoot = '/tracking/groups/'+self.values['tracking_group_id'].to_s+'/items/activity'
            elsif @options[:scope] == 'schedule'
               @urlRoot = '/tracking/groups/'+self.values['tracking_group_id'].to_s+'/items/schedule'
            elsif @options[:scope] == 'permissions'
                #TODO:: we wont know tracking_group_id... 
               @urlRoot = '/tracking/groups/'+self.values['tracking_group_id'].to_s+'/items/permissions'
            else
               @urlRoot = '/tracking/groups/'+self.values['tracking_group_id'].to_s+'/queues/'+self.values['tracking_queue_id'].to_s+'/items'
            end
         end

         def attachment
            Tracking_Attachment['tracking_id' => self.values['tracking_id']]
         end

         def get_data( scope='defaults', file_key=nil )
            call_url = '/tracking/groups/'+self.values['tracking_group_id'].to_s+
                         '/queues/' + self.values['tracking_queue_id'].to_s+
                         '/items/' + self.values['tracking_id'].to_s+
                         '/data?scope='+scope

            if file_key
               call_url += '&file_key='+file_key
            end

            resp = Utils.call( :get, base_xenqu_api + call_url )

            resp['data']
         end

         def set_data( params )
            call_url = '/tracking/groups/'+self.values['tracking_group_id'].to_s+
                         '/queues/' + self.values['tracking_queue_id'].to_s+
                         '/items/' + self.values['tracking_id'].to_s+
                         '/data'

            resp = Utils.call( :post, base_xenqu_api + call_url, { :data => params } )

            resp['data']
         end

         def set_callback( url )
            call_url = '/tracking/groups/'+self.values['tracking_group_id'].to_s+
                         '/queues/' + self.values['tracking_queue_id'].to_s+
                         '/items/' + self.values['tracking_id'].to_s+
                         '/callback'

            resp = Utils.call( :put, base_xenqu_api + call_url, { :callback_url => url } )

            resp
         end

         def unset_callback( url )
            call_url = '/tracking/groups/'+self.values['tracking_group_id'].to_s+
                         '/queues/' + self.values['tracking_queue_id'].to_s+
                         '/items/' + self.values['tracking_id'].to_s+
                         '/callback'

            resp = Utils.call( :delete, base_xenqu_api + call_url, { :callback_url => url } )

            resp
         end

         class File

            def initialize( track, data = {}, options = {} )

               @track = track
               @data = data
               @fileKey = options[:fileKey]
               @scope = options[:scope] || 'defaults'

               @chunkLimit = options[:chunkLimit] || 500000
               @chunkedField = options[:chunkedField] || 'urlData'
               @convertTo = options[:convertTo] || ''

            end

            def fetch
               vals = @track.get_data( @scope, @fileKey )

               return {} if !vals

               if !vals['content_type'].index( 'image/' ).nil?

                  fileUrl = base_xenqu_api + '/files/' + vals['_temp_handle_id'] + '?' #out=json
                  if @convertTo && @convertTo != vals['content_type']
                     fileUrl += 'format=' + @convertTo
                  end

                  vals[@chunkedField] = fileUrl
                  vals.delete( '_temp_handle_id' )

               else

                  vals[@chunkedField] = base_xenqu_api + '/files/' + @values['data']['_temp_handle_id']
                  vals.delete( '_temp_handle_id' )

               end

               vals
            end

            def save

               chunker = FileChunker.new({
                     :url           => 'files',
                     :chunkLimit    => @chunkLimit,
                     :chunkedField  => @chunkedField,
                     :data          => @data
                  })

               temp_id = chunker.send

               @data['file_key'] = @fileKey
               @data['_temp_handle_id'] = temp_id
               @data.delete( @chunkedField )

               @data = @track.set_data( @data )
            end


            private

            def base_xenqu_api
               Xenqu::Models.config.base_xenqu_api
            end

         end

         class Form
            
            class NoPath < Exception
            end
            
            class << self
               attr_reader :keys

               def key( field, options )
                  @keys ||= []
                  opts = options || {}

                  @keys.push({ :field => field, :options => opts })
                  self.instance_variable_set( "@#{field.to_s}", nil )

                  define_method( "#{field.to_s}" ) { self.instance_variable_get( "@#{field.to_s}" ) }
                  if ( opts[:default] )
                     define_method( "#{field.to_s}=" ) { |val| self.instance_variable_set( "@#{field.to_s}", val ) }
                  end
               end

               # Generated a dummy instance with a fixture
               def mock( attr )
                  form = self.new( Tracking_Item.new({}) )
                  form.fixture( attr )
                  form
               end

               def resolve_path( hash, path, quiet = true )
                  if hash.nil?
                    if quiet
                        return nil
                    else
                        raise NoPath
                    end
                  end

                  data = nil
                  if !path.is_a?( Array )
                     path = [path]
                  end

                  len = path.length

                  ptr = hash
                  path.each_with_index do |p,i|
                     if ptr[p].nil?
                        if quiet
                            return nil
                        else
                            raise NoPath
                        end
                     end
                      
                     if i < len - 1
                        ptr = ptr[p]['children'] || ptr[p]
                     else
                        data = ( ptr[p].is_a?( Hash ) && ptr[p]['type'] ) ? ptr[p]['value'] : ptr[p]
                     end
                  end

                  data
               end

               def to_mongo( data )
                  data.nil? ? nil : data.to_hash
               end

               def from_mongo( data )
                  if data.is_a?( self )
                     data
                  elsif data
                     track = Tracking_Item[
                              'tracking_group_id' => data['track']['tracking_group_id'],
                              'tracking_queue_id' => data['track']['tracking_queue_id'],
                              'tracking_id' => data['track']['tracking_id']
                         ]
                     self.new( track, data['data'] )
                  else
                     nil
                  end
               end

            end

            def initialize( track, data = nil )
               @track = track

               if data
                  self.class.keys.map do | key |
                     if data.keys.include?( key[:field].to_s )
                        self.instance_variable_set( "@#{key[:field].to_s}", data[key[:field].to_s] )
                     end
                  end
               end
            end

            def fetched?
               !!@fetched_once
            end

            def to_hash
               Hash[
                  'track' => {
                     'tracking_group_id' => @track.values['tracking_group_id'],
                     'tracking_queue_id' => @track.values['tracking_queue_id'],
                     'tracking_id' => @track.values['tracking_id']
                  },
                  'data' => Hash[self.class.keys.map do | key |
                     [key[:field].to_s, self.instance_variable_get( "@#{key[:field].to_s}" )]
                  end]
               ]
            end

            def fetch
               @fetched_once = true
               vals = @form_data = @track.get_data( 'form' )

               return self if keys.nil?

               keys.select{ |key| !key[:options][:default] }.each do | key |
                  field = key[:field]
                  path = key[:options][:path]
                  isfile = key[:options][:file]

                  val = nil
                  if !path.nil? && path.length > 0
                     val = resolve_path( vals, path.split('.') )
                  end

                  if isfile
                     val = File.new( @track, {}, :scope => 'form', :fileKey => path, :convertTo => key[:options][:convertTo] ).fetch
                  end

                  self.instance_variable_set( "@#{field.to_s}", val )
               end

               self
            end

            ## Enable testing.  Expects a hash of key/values where the key is the
            #  field name defined on the class.
            def fixture( attr )
               @fetched_once = true
               keys.select{ |key| !key[:options][:default] }.each do | key |
                  field = key[:field]
                  self.instance_variable_set( "@#{field.to_s}", attr[field.to_s] )
               end
            end

            def save
               vals = {}
               files = {}

               keys.select{ |key| key[:options][:default] }.each do | key |
                  field = key[:field]
                  path = key[:options][:path]
                  isfile = key[:options][:file]

                  val = self.instance_variable_get( "@#{field.to_s}" )

                  if isfile && !val.nil?
                     pm_data = val['urlData']
                     val.delete( 'urlData' )
                     files[path] = val.merge({ 'urlData' => pm_data })
                  end

                  vals[path] = val

               end

               vals = @track.set_data( vals )

               files.each do | file_key, data |
                  File.new( @track, data, :fileKey => file_key ).save
               end

               self
            end

            protected

            def resolve_path( hash, path )
               self.class.resolve_path( hash, path )
            end

            private

            def keys
               self.class.keys
            end

         end
      end

      class Tracking_Log < Base

         @id_attribute = '_id'

         def urlRoot
            @urlRoot = '/tracking/items/'+self.values['tracking_id'].to_s+'/logs'
         end

         def pin
            self.values['pinned'] = true
            self.save
            self
         end

         def unpin
            self.values['pinned'] = false
            self.save
            self
         end

      end

      class Tracking_Attachment < Base

         @id_attribute = '_id'


         def initialize( data, options = {} )
            @chunkLimit = options[:chunkLimit] || 500000
            @chunkedField = options[:chunkedField] || 'urlData'

            super( data, options )
         end

         def urlRoot
            @urlRoot = '/tracking/attachments/'+self.values['tracking_id'].to_s
         end

         def file_data( files_id, opts )

            convertTo = opts[:convertTo]
            chunkedField = opts[:chunkedField] || 'urlData'

            call_url = '/tracking/attachments/'+self.values['_id']+'/files/'+files_id
            vals = Utils.call( :get, base_xenqu_api + call_url )

            if !vals['content_type'].index( 'image/' ).nil?

               fileUrl = base_xenqu_api + '/files/' + vals['_temp_handle_id'] + '?'
               if convertTo && convertTo != vals['content_type']
                  fileUrl += 'format=' + convertTo
               end

               vals[chunkedField] = fileUrl
               vals.delete( '_temp_handle_id' )

            else

               vals[chunkedField] = base_xenqu_api + '/files/' + vals['_temp_handle_id']
               vals.delete( '_temp_handle_id' )

            end

            vals
         end

         def self.file_data( _id, files_id, opts = {} )
            Tracking_Attachment['_id' => _id].file_data( files_id, opts )
         end
         
         def generate_pdf
            fdata = Utils.call( :get, base_xenqu_api + urlRoot + '/generate_pdf' )
            Net::HTTP.get( URI( base_xenqu_api + '/files/' + fdata['_temp_handle_id'] ) )
         end
         
         def select_template( template_id )
            call_url = '/tracking/attachments/'+self.values['tracking_id'].to_s+'/run_rules/select/'+template_id
            Utils.call( :get, base_xenqu_api + call_url )
         end
         
         def attach_file( data )
            call_url = '/tracking/attachments/'+self.values['_id']+'/files'

            chunker = FileChunker.new({
                  :url           => 'files',
                  :chunkLimit    => @chunkLimit,
                  :chunkedField  => @chunkedField,
                  :data          => data
               })

            temp_id = chunker.send

            data['file_key'] = @fileKey
            data['_temp_handle_id'] = temp_id
            data.delete( @chunkedField )

            data['tracking_id'] = self.values['tracking_id']
            data['attachment_id'] = self.values['_id']
            data['order'] = ( self.values['files'] || [] ).length

            vals = Utils.call( :post, base_xenqu_api + call_url, data )
         end


         def copy_attachments files, recipient
            call_url = '/tracking/attachments/'+self.values['_id']+'/copy'

            data = Hash[
               :recipient_id  => recipient,
               :files_id      => files
            ]

            vals = Utils.call( :post, base_xenqu_api + call_url, data )
         end

         def paste_attachments tokens
            call_url = '/tracking/attachments/'+self.values['_id']+'/paste'

            data = Hash[
               :tokens_id      => tokens
            ]

            vals = Utils.call( :post, base_xenqu_api + call_url, data )
         end

         private

         def base_xenqu_api
            Xenqu::Models.config.base_xenqu_api
         end
      end

   end
end