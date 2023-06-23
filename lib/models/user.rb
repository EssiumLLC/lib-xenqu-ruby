module Xenqu
   module Models

      class User < Base

         def self.info
            Utils.call( :get, base_xenqu_api + '/user/info' )
         end

         def self.accept_invite( aid, iid )
            Utils.call( :get, base_xenqu_api + '/user/accept/' + aid.to_s + '/' + iid.to_s )
         end
         
         def self.send_invite( cid, gid, contact )
            Utils.call( :post, base_xenqu_api + '/tracking/groups/'+gid.to_s+'/user/reset', Hash[ :contact_id => cid.to_i, :contact => contact ] )
         end
         
         def self.recover_password( email )
            Utils.call( :post, base_xenqu_api + '/user/recover', Hash[ :user_email => email ] )
         end
         
         # user_id, provider_id and api_key
         def self.authenticate_api_key( uid, pid, key )
            Utils.call( :post, base_xenqu_api + '/application/user/'+uid+'/provider/'+pid+'/token/'+key )
         end

      end

   end
end
