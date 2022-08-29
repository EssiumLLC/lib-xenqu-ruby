#####################################################################################
#
# These examples make use of the Xenqu Ruby API Library gem:
# https://github.com/EssiumLLC/lib-xenqu-ruby
#
#
# The assuption is you know both the contact id and tab you want to 
# perform operations against.
# gid => tracking group id (tab)
# pid => record contact id (worker)

# If you need a contact, add one
# https://apidocs.xenqu.com/#7969a360-ee09-41a8-9299-05a5f0ffb7fb


# Get Tab - this has the owner_id of the master instance
# account which is a good fallback for non-primary actor 
# assignments.
# https://apidocs.xenqu.com/#764d0965-219e-41a0-b0cc-5896c39012c8
group = ::Pryde::Models::Tracking_Group['tracking_group_id' => gid]
group.fetch

# Get Record 
# https://apidocs.xenqu.com/#3bd6f73c-b25e-4d3f-8695-5e58d35df88d
record = ::Xenqu::Models::Tracking_Actor[
                'tracking_group_id' => gid,
                'contact_id' => pid
             ]

record.fetch

#####################################################################################
#
# Find a template of queues and items and add those to a record
# using a template is easier than adding items one-by-one.
#

# Get Templates
# https://apidocs.xenqu.com/#c1386fb4-46fb-4934-91c4-e811f0fb56de
templates = ::Xenqu::Models::Queue_Template['tracking_group_id' => gid].fetch
annuals = templates.detect{ | t | t.values['title'] =~ /Annual/ }
annuals.values['tracking_group_id'] = gid

# Get Template
# https://apidocs.xenqu.com/#76dd3859-1f6f-479d-bd58-64b742cf8bdf
annuals.fetch

# This assumes the record already exists.  A new contact will have no queues array
# so the section should be 0.  You can also put everything in section 0
# sections are used to segment a record's queues
add_to_section = record.values['queues'].map{ |q| q['section'] }.max + 1

# This example shows all minimum data to add queues:
# The concept of "primary actor" means the subject
# of the record (ie the candidate or worker) is assumed
# the queue's primary actor role ensures the same role
# within an items actor roles list force assigns properly
# the system will not let you improperly set the the 
# contact ID on this assignment.  All other roles can
# be any contact ID and are classified as secondary roles.
template['queues'].each do | baseq |

    newq = ::Pryde::Models::Tracking_Queue.new({
           'progress_bin_id' => nil, 
           'tracking_group_id' => gid,
           'title' => baseq['title'],
           'primary_actor_id' => pid,
           'primary_actor_role' => 'Worker',
           'primary_actor_role_slug' => 'worker',
           'section' => add_to_section, 
           'force_ordering' => baseq['force_ordering'],
           'items' => []
        })

    baseq['items'].each_with_index do | basei, idx |

        actors = basei['item']['actors'].map do | actor |
            isw = ( actor['actor_role_slug'] == 'worker' )

            {
               'order' => actor['order'],
               'actor_role' => actor['actor_role'],
               'actor_role_slug' => actor['actor_role_slug'],
               'contact_id' => if isw
                                 pid
                               else
                                 group.values['owner_id']
                               end
            }
        end

        newq.values['items'].push({
            'order' => basei['order'],
            'item_id' => basei['item_id'],
            'tracking_id' => idx + 1,
            'tracking_library_id' => basei['tracking_library_id'],
            'item' => {
               'actors' => actors
            }
        })

    end
    
    # Add Queue
    # https://apidocs.xenqu.com/#38e912b5-5c85-47f7-9800-299c5d66e773
    newq.save
end


#####################################################################################
#
# Find an item from a library and add to an existing queue
# You need to know the title of the item to add.  
#

queue = # If you know the ID, fetch it from the end point.
        # otherwise, you can search for a queue from a record.

# Finding the item is a 3 step process of (1) finding the item in
# the master item list, (2) finding which library(s) contain 
# the item, and (3) from that list using the item id in (1) to 
# isolate which library holds your item.  In general, items are
# only used in one library but that's not a requirement so you
# must handle the situation when an item appears in more than one
# library.

# Get Libraries
# https://apidocs.xenqu.com/#2d7ae85c-9ea3-4832-83f5-14f982756c20
libs = group.libraries

# Get Items
# https://apidocs.xenqu.com/#f89c6d8b-b7f6-48a2-9ab7-5ffc0029b326
items = group.items.fetch.map{ |item| item.values }


fnd = nil
add_item = nil
library_id = nil
items.select{ |i| i['title'] =~ /^My Item Title/ }.each do | icnd |

   if !fnd
      # Search Libraries
      # https://apidocs.xenqu.com/#ee9ddc77-a8a6-49b7-a7d7-f9a72c44d00c
      fnd = libs.find({ :title => icnd['title'] })
   end

   tli = fnd['libraries'].
            detect{ |l|
               l['included'] > 0 &&
                  ONLY_THESE_LIBS.include?( l['tracking_queue_id'] ) ) &&
                    l['items'].any?{ | itm | itm['item_id'] == icnd['item_id'] }
            }

   if tli
      add_item = icnd
      library_id = tli['tracking_queue_id']
   end

end

raise "Unable to find item" unless add_item
raise "Unable to find library" unless library_id

actors = add_item['actors'].map do | actor |

      cid = if actor['actor_role_slug'] == 'worker'
         runner.globals['primary_actor']['contact_id']
      elsif opts[:actor_map] && opts[:actor_map][actor['actor_role_slug']]
         opts[:actor_map][actor['actor_role_slug']]['contact_id']
      else
         group.values['owner_id']
      end

      actor.merge({ 'contact_id' => cid })
end

queue.values['items'].push({
      'order' => queue.values['items'].length,
      'item_id' => add_item['item_id'],
      'tracking_library_id' => library_id,
      'item' => {
         'actors' => actors
      }
})

# Edit Queue
# https://apidocs.xenqu.com/#9c87cc46-1abb-4c76-a973-4ad3a8e5aec9
queue.save
