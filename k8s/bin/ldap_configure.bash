#!/bin/bash

#docker run --detach --rm --name openldap \
#   --env LDAP_ADMIN_USERNAME=admin \
#   --env LDAP_ADMIN_PASSWORD=adminpassword \
#   --env LDAP_USERS="user01,user02" \
#   --env LDAP_PASSWORDS="Mongodb1,Mongodb1" \
#   -p "389:1389" bitnami/openldap:latest

source init.conf
kubectl config set-context $(kubectl config current-context) --namespace=${namespace}
serviceName="openldap-svc-ext"
if [[ $serviceType == "NodePort" ]]
then
    slist=( $(bin/get_hns.bash -s "${serviceName}" ) ) 
    hostName="${slist[0]%:*}"
    eval port=$(    kubectl get svc/${serviceName} -o jsonpath={.spec.ports[0].nodePort} )
else
    eval hostName=$(    kubectl get svc/${serviceName} -o jsonpath={.status.loadBalancer.ingress[0].hostname} ) 
    eval port=$(  kubectl get svc/${serviceName} -o jsonpath={.spec.ports[0].targetPort} )
fi
ldapServer="ldap://${hostName}:${port}"

# add User TL
ldapmodify -H ${ldapServer} -x -a -w adminpassword -D cn=admin,dc=example,dc=org <<EOF
dn: cn=Thomas.Luckenbach,ou=users,dc=example,dc=org
cn: Thomas
sn: Luckenbach
givenName: Thomas
objectClass: posixAccount
objectClass: inetOrgPerson
uid: thomas.luckenbach
mail: thomas.luckenbach@mongodb.com
userPassword: Mongodb1$
uidNumber: 1002
gidNumber: 1002
homeDirectory: /Users/tluck
EOF

# add User SL
ldapmodify -H ${ldapServer} -x -a -w adminpassword -D cn=admin,dc=example,dc=org <<EOF
dn: cn=Suzanne.Luckenbach,ou=users,dc=example,dc=org
cn: Suzanne
sn: Luckenbach
givenName: Suzanne
objectClass: posixAccount
objectClass: inetOrgPerson
uid:  suzanne.luckenbach
mail: suzanne.luckenbach@mongodb.com
userPassword: Mongodb1$
uidNumber: 1003
gidNumber: 1003
homeDirectory: /Users/suzanne
EOF

# put TL in readers group -  DB users
ldapmodify -H ${ldapServer} -x -c -w adminpassword -D cn=admin,dc=example,dc=org <<EOF
dn: cn=readers,ou=users,dc=example,dc=org
add: member
member: cn=Thomas.Luckenbach,ou=users,dc=example,dc=org
EOF

# create managers group and add users  - org ossociations
ldapadd -H ${ldapServer} -x -c -w adminpassword -D cn=admin,dc=example,dc=org <<EOF
dn: cn=managers,ou=users,dc=example,dc=org
cn: managers
objectClass: groupOfNames
member: cn=Thomas.Luckenbach,ou=users,dc=example,dc=org
member: cn=Suzanne.Luckenbach,ou=users,dc=example,dc=org
EOF

ldapsearch -H ${ldapServer} -x -b 'dc=example,dc=org' 

