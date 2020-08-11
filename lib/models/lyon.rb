module Xenqu
    module Models
        module Lyon
        
            class WebService < Base

                @id_attribute = 'account_id'

                def urlRoot
                    @urlRoot = '/lyon/'+self.values['account_id'].to_s
                end
                
                def get( url, params )
                    Utils.call( :get, base_xenqu_api + urlRoot + url, params )
                end
                
                def post( url, params )
                    Utils.call( :post, base_xenqu_api + urlRoot + url, params )
                end
            end
        end
    end
end