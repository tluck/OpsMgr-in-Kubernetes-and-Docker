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
names=("$@")

template=cert_template.yaml
yaml="certs_${name}.yaml"
cat ${template} | sed \
    -e "s|ISSUERNAME|$issuerName|" \
    -e "s|NAMESPACE|$namespace|" \
    -e "s|CERTNAME|$name|g" > "${yaml}"

# printf "%s\n" "    - *.${name}-svc.${namespace}.svc.cluster.local" >> "${yaml}"
for n in ${names[*]}
do
printf "%s\n" "    - \"${n}\"" >> "${yaml}"
done
