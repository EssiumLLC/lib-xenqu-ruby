module Xenqu
   module Models

      # DO NOT FETCH SPECIFIC ACCOUNT FOR NOW: TODO FIX IN Xenqu
      class Account < Base

         @id_attribute = '_id'

         def urlRoot
            @urlRoot = '/accounts'
         end

         def users
            Account_User[ 'account_id' => @values['_id'] ]
         end
      end

      class Account_User < Base
         @id_attribute = '_id'

         def self.invite opts = Hash[]

            opts[ 'status' ] = 'invited'
            opts[ 'user_type' ] = 'invited'
            opts[ 'settings' ] = Hash[]

            u = self.new( opts )
            u.save

            u
         end

         def urlRoot
            @urlRoot = '/accounts/'+self.values['account_id'].to_s+'/users'
         end

      end

   end
end