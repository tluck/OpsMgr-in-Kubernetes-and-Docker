source init.conf

curl --insecure --user "${publicKey}:${privateKey}" --digest \
 --header "Accept: application/json" \
 --header "Content-Type: application/json" \
 --request POST "${opsMgrExtUrl}/api/public/v1.0/groups/${projectId}/logCollectionJobs?pretty=true" \
 --data '
   {
     "resourceType": "REPLICA_SET",
     "resourceName": "MY-REPLICA-SET",
     "redacted": false,
     "sizeRequestedPerFileBytes": 10000000,
     "logTypes": [
         "MONGODB"
     ]
   }'
# -o log-req.json \

