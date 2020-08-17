source init.conf

TAB=$'\t'

grep "^[0-9].*opsmanager-svc.mongodb.svc.cluster.local" /etc/hosts > /dev/null 2>&1
if [[ $? == 0 ]]
then
    # replace ho]t entry
    printf "%s\n" "Replacing host entry:"
    printf "%s\n" "${opsMgrExtIp}${TAB}opsmanager-svc.mongodb.svc.cluster.local" 
    sudo sed -E -i .bak -e "s|^[0-9].*(opsmanager-svc.mongodb.svc.cluster.local)|${opsMgrExtIp}${TAB}\1|" /etc/hosts
else
    # add host entry
    printf "%s\n" "Adding host entry:"
    printf "%s\n" "${opsMgrExtIp}${TAB}opsmanager-svc.mongodb.svc.cluster.local" | sudo tee -a /tmp/hosts
fi
