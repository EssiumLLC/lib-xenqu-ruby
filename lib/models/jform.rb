module Xenqu
   module Models
      
      class FormFieldConflict < StandardError; end
      
      class Jform_Definition < Base
         @id_attribute = 'definition_id'

         def urlRoot
            @urlRoot = '/jform/definition/'
         end

         def self.fetch_live_by_revision( revid )
            params = { :status => 10, :revision_id => revid }
            defn = self.new
            defn.fetch( params )
            defn
         end
      end

      class Jform_Field < Base
         @id_attribute = 'state_id'

         def urlRoot
            if self.values['page_id'].blank?
               @urlRoot = '/jform/instance/' + self.values['instance_id'].to_s + '/sudofield'
            else
               @urlRoot = '/jform/instance/' + self.values['instance_id'].to_s + '/page/' + self.values['page_id'].to_s + '/field'
            end
         end

      end

      class Jform_Instance < Base
         @id_attribute = 'instance_id'

         def urlRoot
            @urlRoot = '/jform/instance'
         end

         def dpi
            @values['definition']['dpi']
         end

         def field( tag )
            @fields[tag]
         end

         def prepare( params = {} )
            self.fetch( params.merge( :read_only => true ) )

            @fields = {}
            @values['definition']['pages'].each_with_index do | page, pidx |

               page['fields'].each do | field |

                  @fields[field['tag']] = {
                     'page_index' => pidx,
                     'page_id' => page['_id'],
                     'state_id' => field['_id'],
                     'fid' => field['fid'],
                     'x' => field['x'].to_f,
                     'y' => field['y'].to_f,
                     'width' => field['width'].to_f,
                     'height' => field['height'].to_f,
                     'value' => field['value'],
                     'active' => field['active']
                  }
               end

            end
            
            @values['definition']['sudo_fields'].each do | field |

                @fields[field['tag']] = {
                     'state_id' => field['_id'],
                     'fid' => field['fid'],
                     'value' => field['value'],
                     'active' => field['active']
                }

            end            

         end

         def lock
            tmp = self.class.new({
               'instance_id' => self.values['instance_id'],
               'override' => true,
               'lock' => true
            })

            tmp.save
         end

         def kick( async=false )
            tmp = self.class.new({
               'instance_id' => self.values['instance_id'],
               'kick' => async ? 'async' : true
            })

            tmp.save
         end

         def unlock
            tmp = self.class.new({
               'instance_id' => self.values['instance_id'],
               'unlock' => true
            })

            tmp.save
         end

         def set( data, opts = {} )

            missing = data.map{ | tag, value | @fields[tag] ? nil : tag }.compact

            raise "Field(s) #{missing.join(', ')} not found in definition" if missing.length > 0 && !opts[:skip_field_validation]

            retries = 5 ; retry_list = {} ; run_list = data
            begin

               run_list.each do | tag, value |

                  good_field = !missing.include?( tag ) && @fields[tag]['active'] # check if field exists and is active
                  can_be_affected = !( @fields[tag]['locked'] || @fields[tag]['disabled'] ) #check if the field isn't locked or disabled

                  if good_field && can_be_affected

                     fld = Jform_Field.new({
                           'instance_id' => self.values['instance_id'],
                           'page_id' => @fields[tag]['page_id'],
                           'state_id' => @fields[tag]['state_id'],
                           'raw_value' => ( value.is_a?( Array ) ? value : value.to_s ),
                           'fid' => @fields[tag]['fid']
                        })

                     begin
                        fld.save

                        # if the field metadata says it isn't locked or disabled, but its values are still the same
                        # then it probably means the field metadata was incorrect or was not updated somehow.
                        # Or, they really are the same, but we (the runner) has zero way to discern that.
                        # Although this is old code, this is now the fallback
                        if !opts[:skip_value_check] && fld.values['raw_value'].to_s != value.to_s

                           # May be locked or disabled and another
                           # field put will enable it.  Put it back
                           # on the list to retry.
                           retry_list[tag] = value
                        end
                     rescue

                        sleep( 1 )
                        retry_list[tag] = value
                     end

                  elsif good_field && !can_be_affected
                     # if it is disabled/locked, another field may enable it. retry it!
                     retry_list[tag] = value
                  end

               end

               retries -= 1
               # we don't need to spend all this time retrying if there is nothing to retry...
               if retry_list.keys.length > 0 && retries > 0
                  sleep( 3 )
                  run_list = retry_list
                  retry_list = {}
               elsif retries > 0 # if we hit 0 retries remaining, we need to make sure the error can see what wasn't mapping
                  run_list = {}
               end

            end while run_list.keys.length > 0 && retries > 0
            
            raise FormFieldConflict.new("#{self.values["tracking_id"]} - #{run_list.keys.join(",")}") if run_list.keys.length > 0 && opts[:error_on_conflict]
            
         end

         # files should be an array of file_ids, it can be a single file_id in a non-array, the endpoint does convert
         # recipient should be the contact_id of the user allowed to view the files
         #
         # A lock is not required for copy attachments
         #
         # will return a hash where the key is the original file_id and the value is the token for that file_id
         def copy_attachments files, recipient
            #return if !self.values['definition']['attachments']['enabled']
            iid = self.values['instance_id'].to_s
            call_url = '/jform/instance/' + iid + '/attachments/' + self.values['definition']['attachments']['_id'].to_s + '/copy'

            data = Hash[
               :recipient_id  => recipient,
               :files_id      => files
            ]

            vals = Utils.call( :post, base_xenqu_api + call_url, data )
         end

         ## copying tokens into the attachment is a two part process
         ## first you must copy the tokens and get the file_ids, this will place the files into the file pool
         ## then you must build the attachments such that the files are in the buckets you want them to be in
         ## The form should be locked prior to using paste_attachments or save_attachments

         # provide an array of tokens
         #
         # will return an array of hashes with "_id" and "description" for the files that were added to the file pool
         def paste_attachments tokens
            return if !self.values['definition']['attachments']['enabled']
            call_url = '/jform/instance/'+ self.values['instance_id'].to_s() +'/attachments/' + self.values['definition']['attachments']['_id'].to_s + '/paste'

            data = Hash[
               :tokens_id      => tokens
            ]

            vals = Utils.call( :post, base_xenqu_api + call_url, data )
         end

         ## buckets is an array
         ## each array element should be a hash of { "tag" => string, "attachments" => array }
         ## the tag should be the tag of the bucket as defined in the definition
         ## the array should be an array of hashes in the same format as what is returned from paste_attachments
         ## this function is not additive, meaning if there are existing attachments you need to include them in the put
         ## otherwise they will be nuked
         ##
         ## [
         ##    Hash[ "tag" => "files", "attachments" => form.paste_attachments( tokens ) ]
         ##
         ## ]
         def save_attachments buckets
            return if !self.values['definition']['attachments']['enabled']
            call_url = '/jform/instance/'+ self.values['instance_id'].to_s() +'/attachments/' + self.values['definition']['attachments']['_id'].to_s

            data = Hash[
               :buckets      => buckets
            ]

            vals = Utils.call( :put, base_xenqu_api + call_url, data )
         end
         
         def upload_attachment( field, files, options = {} )

            files = !files.is_a?(Array) ? [files] : files
            files_ids = []

            files.each do |file|
              chunker = FileChunker.new({
                  :url           => 'files',
                  :chunkLimit    => options[:chunkLimit] || 500000,
                  :chunkedField  => options[:chunkedField] || 'urlData',
                  :data          => file
                })

              temp_id = chunker.send
          
              call_url = '/jform/instance/' + self.values['instance_id'].to_s + '/file/'
              
              data = { 
                  :content_type => file['content_type'],
                  :filename => file['filename'],
                  :for_id => field['state_id'],
                  :for_type => 'field',
                  :_temp_handle_id => temp_id
              }
              
              ret = Utils.call( :post, base_xenqu_api + call_url, data )

              files_ids.push(ret['files_id'])
            end
            
            call_url = '/jform/instance/' + self.values['instance_id'].to_s + '/sudofield/' + field['state_id']            
            ret = Utils.call( :put, base_xenqu_api + call_url, { :fid => field['fid'], :raw_value => files_ids } )
            
         end
         
         def download_attachments( fields = nil )
             
             call_url = '/jform/instance/' + self.values['instance_id'].to_s + '/file/'
             
             attachments = self.values['definition']['sudo_fields'].
                select{ | s | s['instanceOf'] == 'attachment' && !s['disabled'] && s['active'] && ( fields.nil? || ( !fields.nil? && fields.include?( s['fid'] ) ) ) }.
                map{ | s | s['mode_data'].map{ |k,v| v.slice( 'files_id', 'content_type', 'filename' ) } }.
                flatten

             attachments.map do | at |
             
                ref = ::Xenqu::Models::Utils.call( :get, base_xenqu_api + call_url + at['files_id'] )
                at['urlData'] = base_xenqu_api + '/files/' + ref['_temp_handle_id']
                
                at
             end
         end
         
         def copy_pdf( recipient, options=Hash[] )
            chk = self.generate_pdf( options )
            fid = chk.values['definition']['pdf_id']

            vals = Utils.call( :get, base_xenqu_api + urlRoot + '/' + self.values['instance_id'].to_s + '/pdf/' + chk.values['definition']['pdf_id'] +'/copy/' + recipient.to_s )
            vals[ 'token' ]
         end

         def generate_pdf( options = Hash[] )
            
            self.fetch unless self.values['definition']
            
            ret = Utils.call( :post, base_xenqu_api + urlRoot + '/' + self.values['instance_id'].to_s + '/pdf/', options )

            chk = nil
            tries = 0
            begin
               sleep( 5 )

               chk = self.class.new({
                  'instance_id' => self.values['instance_id']
               })

               chk.fetch

               tries += 1
            end while chk.values['definition']['pdf_id'] == self.values['definition']['pdf_id'] && tries < 30
            
            sleep( 3 )
            
            chk
         end

         def to_pdf( options = Hash[] )
            chk = self.generate_pdf( options )
            
            begin
                retries ||= 0
                fdata = Utils.call( :get, base_xenqu_api + urlRoot + '/' + self.values['instance_id'].to_s + '/file/' + chk.values['definition']['pdf_id'] )
            rescue => e
                sleep( 3 )
                retry if (retries += 1) < 3
                raise e
            end

            Net::HTTP.get( URI( base_xenqu_api + '/files/' + fdata['_temp_handle_id'] ) )
         end


         private

         def base_xenqu_api
            Xenqu::Models.config.base_xenqu_api
         end
      end

   end
end