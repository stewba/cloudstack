#!/usr/bin/

require 'cloud_stack_client'
require 'json'
require 'pp'

class Cloudstack
    
    def initialize(api_databag,credentials_name) 
        cloudstack_databag = Chef::DataBagItem.load(api_databag, credentials_name)
        @client = CloudStackClient::Connector.new(:api_uri => cloudstack_databag["portal"], :api_key => cloudstack_databag["apikey"], :secret_key => cloudstack_databag["seckey"]); 
    end

    # get a full api response for all vms .... this will be very large, but a good starting point
    def getVirtualMachinesResponse
        return @client.listVirtualMachines(:response => :json,:state => :running);
    end

    #get a full volumes response for a given vm
    def getVolumesResponse(vmid)
        return @client.listVolumes(:response => :json,:virtualmachineid => vmid);
    end

    #get an array of volume ids for a given vm
    def getVolumeIds(vmid)
        vol_response = getVolumesResponse(vmid);
        vol_ids = []
        if(vol_response['listvolumesresponse'].has_key?('volume'))
         vol_response['listvolumesresponse']['volume'].each { |vol_entry|
             vol_ids.push(vol_entry['id'])
         }
        end
        return vol_ids
    end

    #get a full response for the snapshot policy of the given volume id
    def getSnapshotPolicyResponse(volid)
        return @client.listSnapshotPolicies(:response => :json, :volumeid => volid)
    end

    # find out is a snapshot pollicy is set
    def snapshotPolicySet?(volid)
        snapshotResponse = getSnapshotPolicyResponse(volid)
        if(snapshotResponse['listsnapshotpoliciesresponse'].has_key?('snapshotpolicy'))
            return true
        end
        return false
    end

    #get a vmid from a node name
    def getVmId(nodename)
        vm_response = getNodeVolumesResponse(nodename)
        if(!vm_response.nil?)
            return vm_response[0]['virtualmachineid']
        end
        return nil
    end

    #create a snapshot policy for a volume
    #example paramters:
    #("WEEKLY",2,"00:19:7","Australia/Hobart","v245fgrw-q3rfc3-c24rf534")
    def createSnapshotPolicy(intervalType,maxSnaps,schedule,timezone,volumeID)
        return @client.createSnapshotPolicy(:response => :json, 
                                     :intervaltype => intervalType,
                                     :maxsnaps => maxSnaps,
                                     :schedule => schedule,
                                     :timezone => timezone,
                                     :volumeid => volumeID);
    end

    # get full response for for volumes for a given node (by name)
    def getNodeVolumesResponse(nodename)
            #vm_response = getVirtualMachines(:name => nodename)
            vm_response = @client.listVirtualMachines(:response => :json,:name => nodename)

            if (!vm_response['listvirtualmachinesresponse'].empty?)
                vm_id = vm_response['listvirtualmachinesresponse']['virtualmachine'][0]['id']
                volumes = getVolumesResponse(vm_id)['listvolumesresponse']['volume']
            end
    end

    #takes a hash with either nodename or volumeid, if both are set returns volumeid response
    #returns the number of snapshots that are set (note that it could be more than 1)
    def volumeSnapshotIsSet(options = {})
        count = 0
        if(!options[:volumeid].nil?)
             if(snapshotPolicySet?(volume_id))
                    count += 1
                end
        elsif(!options[:nodename].nil?)
            volumeIdArray = getVolumeIds(getVmId(options[:nodename]))
            volumeIdArray.each{ |volume_id|
                if(snapshotPolicySet?(volume_id))
                    count += 1
                end
            }
        else
            # if we got here then we didnt get an expected parameter
            count = -1
        end
        return count
    end
end
