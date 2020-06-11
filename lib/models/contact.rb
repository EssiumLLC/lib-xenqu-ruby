module Xenqu
   module Models

      class Contact < Base

         @id_attribute = 'contact_id'

         def urlRoot
            @urlRoot = '/contact'
         end

      end

   end
end