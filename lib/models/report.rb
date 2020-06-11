module Xenqu
   module Models

      class Report_Job < Base
         @id_attribute = 'job_id'

         def initialize( data, options = {} )
            super( data, options )
         end

         def urlRoot
            @urlRoot = '/reporting/results/?job_id='+self.values['job_id'].to_s+'&status=3&count=10&offset=0&sortby=run_date:asc'
         end
      end
      
      class Report_Result < Base
         @id_attribute = 'report_id'

         def initialize( data, options = {} )
            super( data, options )
         end

         def urlRoot
            @urlRoot = '/reporting/results'
         end
      end

   end
end
