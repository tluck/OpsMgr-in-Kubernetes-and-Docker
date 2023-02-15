#!/bin/bash

#docker run --detach --rm --name openldap \
#   --env LDAP_ADMIN_USERNAME=admin \
#   --env LDAP_ADMIN_PASSWORD=adminpassword \
#   --env LDAP_USERS="user01,user02" \
#   --env LDAP_PASSWORDS="Mongodb1,Mongodb1" \
#   -p "389:1389" bitnami/openldap:latest

source init.conf
hostName=$( kubectl get svc openldap-svc-ext -o jsonpath={.status.loadBalancer.ingress[].hostname} )

# add User TL
ldapmodify -H ldap://${hostName}:389 -x -a -w adminpassword -D cn=admin,dc=example,dc=org <<EOF
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

# put TL in readers group - global admins
ldapmodify -H ldap://${hostName}:389 -x -c -w adminpassword -D cn=admin,dc=example,dc=org <<EOF
dn: cn=readers,ou=users,dc=example,dc=org
add: member
member: cn=thomas.Luckenbach,ou=users,dc=example,dc=org
EOF

# create managers group and add TL - org ossociations
ldapadd -H ldap://${hostName}:389 -x -c -w adminpassword -D cn=admin,dc=example,dc=org <<EOF
dn: cn=managers,ou=users,dc=example,dc=org
cn: managers
objectClass: groupOfNames
member: cn=thomas.Luckenbach,ou=users,dc=example,dc=org
EOF

ldapsearch -H ldap://${hostName}:389  -x -b 'dc=example,dc=org' 

