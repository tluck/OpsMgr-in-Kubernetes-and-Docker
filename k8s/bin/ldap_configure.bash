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
    slist=( $(get_hns.bash -s "${serviceName}" ) ) 
    hostName="${slist[0]%:*}"
    eval port=$(    kubectl get svc/${serviceName} -o jsonpath={.spec.ports[0].nodePort} )
else
    eval hostName=$(    kubectl get svc/${serviceName} -o jsonpath={.status.loadBalancer.ingress[0].hostname} ) 
    if [[ $hostName == "" ]]
    then
    slist=( $(get_hns.bash -s "${serviceName}" ) ) 
    hostName="${slist[0]%:*}"
    fi
    eval port=$(  kubectl get svc/${serviceName} -o jsonpath={.spec.ports[0].targetPort} )
fi
ldapServer="ldap://${hostName}:${port}"

ldapadd -H ${ldapServer} -x -c -w configpassword -D cn=admin,cn=config <<EOF
dn: cn=module,cn=config
cn: module 
objectClass: olcModuleList
olcModulePath: /opt/bitnami/openldap/lib/openldap
olcModuleLoad: memberof.so
EOF

ldapadd -H ${ldapServer} -x -c -w configpassword -D cn=admin,cn=config <<EOF
dn: olcOverlay=memberof,olcDatabase={2}mdb,cn=config
objectClass: olcOverlayConfig
objectClass: olcMemberOf
olcOverlay: memberof
olcMemberOfRefint: TRUE
EOF

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

#ldapmodify -H ${ldapServer} -x -c -w adminpassword -D cn=admin,dc=example,dc=org <<EOF
#dn: cn=readers,ou=users,dc=example,dc=org
#changetype: modify
#delete: member
#member: cn=dbAdmin,ou=users,dc=example,dc=org
#member: cn=User01,ou=users,dc=example,dc=org
#member: cn=User02,ou=users,dc=example,dc=org
#EOF

# put users in readers group -  DB users
ldapmodify -H ${ldapServer} -x -c -w adminpassword -D cn=admin,dc=example,dc=org <<EOF
dn: cn=readers,ou=users,dc=example,dc=org
add: member
member: cn=Thomas.Luckenbach,ou=users,dc=example,dc=org
EOF

# create dbusers group and add users  - org ossociations
ldapadd -H ${ldapServer} -x -c -w adminpassword -D cn=admin,dc=example,dc=org <<EOF
dn: cn=dbusers,ou=users,dc=example,dc=org
cn: dbusers
objectClass: groupOfNames
member: cn=dbAdmin,ou=users,dc=example,dc=org
member: cn=User01,ou=users,dc=example,dc=org
member: cn=User02,ou=users,dc=example,dc=org
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

#ldapsearch -H ${ldapServer} -x -b 'dc=example,dc=org' 
#ldapsearch -H ${ldapServer} -x -b 'dc=example,dc=org' dn cn=Thomas.Luckenbach,ou=users,dc=example,dc=org dn memberof

printf "%s\n" "created ldapServer=ldap://${hostName}:${port}"
