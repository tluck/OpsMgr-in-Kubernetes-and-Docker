#!/bin/bash

d=$( dirname "$0" )
cd "${d}"

name="$1"
if [[ "$name" == "" ]]
then
    printf "%s\n" "Exit - need resource name"
    exit 1
fi
shift
cname="$1"
shift
dnsHorizon=("$@")

if [[ ! -e "${name}.pem" ]]
then
printf "\n%s\n" "Making ${name}.pem for ${cname} and ${dnsHorizon[@]} ..."

# generate request
if [[ "${dnsHorizon[0]}" != "" ]]
then
cat <<EOF | cfssl gencert -config ca-config.json -ca ca.crt -ca-key ca.key -profile kubernetes - | cfssljson -bare node
{
  "hosts": [
    "${cname}", "${dnsHorizon[0]}", "${dnsHorizon[1]}", "${dnsHorizon[2]}"
  ],
  "CN": "${cname}",
  "key": {
    "algo": "rsa",
    "size": 4096
  },
  "names": [
    {
      "O": "system:nodes"
    }
  ]
}
EOF

else

cat <<EOF | cfssl gencert -config ca-config.json -ca ca.crt -ca-key ca.key -profile kubernetes - | cfssljson -bare node
{
  "hosts": [
    "${cname}"
  ],
  "CN": "${cname}",
  "key": {
    "algo": "rsa",
    "size": 4096
  },
  "names": [
    {
      "O": "system:nodes"
    }
  ]
}
EOF

fi

mv node-key.pem "${name}.key"
mv node.pem "${name}.crt"
mv node.csr "${name}.csr"
cat "${name}.key" "${name}.crt" > "${name}.pem"

# clean up
#rm ${name}.key
#rm ${name}.crt
#rm ${name}.csr

printf "%s\n" "Made ${name}.pem"
fi

