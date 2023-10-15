#!/bin/bash

cat <<EOF |cfssl gencert -initca - | cfssljson -bare ca -
{
    "CN": "kubernetes",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "O": "MongoDB",
            "C": "US",
            "ST": "CA",
            "L": "San Francisco"
        }
    ]
}
EOF

mv ca-key.pem ca.key
mv ca.pem ca.crt
