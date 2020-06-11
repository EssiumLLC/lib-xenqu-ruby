module Xenqu
   module Models

      class User < Base

         def self.info
            Utils.call( :get, base_xenqu_api + '/user/info' )
         end

         def self.accept_invite( aid, iid )
            Utils.call( :get, base_xenqu_api + '/user/accept/' + aid.to_s + '/' + iid.to_s )
         end

      end

   end
end
