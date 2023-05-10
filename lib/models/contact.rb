module Xenqu
   module Models

      class Contact < Base

         @id_attribute = 'contact_id'

         def urlRoot
            @urlRoot = '/contact'
         end

      end

      class Contacts < Base 

        def urlRoot 
          @urlRoot = '/contact'
        end

        def self.search_contacts(params)
          Utils.call( :get, base_xenqu_api + '/contact', params )
        end

      end

   end
end