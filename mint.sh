set -x

cardano-cli address key-gen \
    --verification-key-file "policy-$1.vkey" \
    --signing-key-file "policy-$1.skey"

KEYHASH=$(cardano-cli address key-hash --payment-verification-key-file "policy-$1.vkey")
CURRENTSLOT=$(cardano-cli query tip --mainnet | jq '.slotNo')
BEFORESLOT=$(expr $CURRENTSLOT + 100000)

cat <<EOF > "policy-$1.script"
{
  "type": "all",
  "scripts":[
    {
      "type": "sig",
      "keyHash": "$KEYHASH"
    },
    {
      "type": "before",
      "slot": $BEFORESLOT
    }
  ]
}
EOF


POLICYID=$(cardano-cli transaction policyid --script-file "policy-$1.script")

cat <<EOF > "policy-$1-metadata.json"
{
   "721": {
     "$POLICYID": {
        "$1": {
           "image": "ipfs://$IPFSHASH",
           "name": "$1"
        }
     }
  }
}
EOF

cardano-cli transaction build-raw \
	     --mary-era \
	     --invalid-before $CURRENTSLOT \
             --invalid-hereafter $BEFORESLOT \
             --fee 0 \
             --tx-in "${TXIN}${TXINID}" \
             --tx-out "${2}+1000000" \
	     --tx-out "$OUTADDR+1000000 +${AMOUNT:-1} ${POLICYID}.${1}" \
             --mint="${AMOUNT:-1} ${POLICYID}.${1}" \
             --out-file matx.raw \
             --json-metadata-no-schema \
	     --metadata-json-file "policy-$1-metadata.json"

MINFEE=$(cardano-cli transaction calculate-min-fee \
  --tx-body-file matx.raw \
  --tx-in-count 1 \
  --tx-out-count 2 \
  --witness-count 2 \
  --mainnet \
  --protocol-params-file "$HOME/protocol.json" | cut -d" " -f1)

CURRENTVALUE=$(cardano-cli query utxo   --address "$2"   --mainnet   --mary-era | grep $TXIN | cut -f14 -d" ")
MINOUTPUT="2000000"
RETAIN=$(expr $CURRENTVALUE - $MINFEE - $MINOUTPUT)

cardano-cli transaction build-raw \
             --mary-era \
	     --invalid-before $CURRENTSLOT \
             --invalid-hereafter $BEFORESLOT \
             --fee $MINFEE \
             --tx-in "${TXIN}${TXINID}" \
             --tx-out "${2}+${RETAIN}" \
	     --tx-out "$OUTADDR+${MINOUTPUT}+${AMOUNT:-1} ${POLICYID}.${1}" \
             --mint="${AMOUNT:-1} ${POLICYID}.${1}" \
             --out-file matx.raw \
             --json-metadata-no-schema \
             --metadata-json-file "policy-$1-metadata.json"

#cardano-cli transaction witness \
#  --tx-body-file matx.raw \
#  --signing-key-file "policy-$1.skey" \
#  --mainnet \
#  --out-file matx.policy.witness
#
#cardano-cli transaction witness \
#  --tx-body-file matx.raw \
#  --signing-key-file "pay.skey" \
#  --mainnet \
#  --out-file matx.pay.witness
#
#cardano-cli transaction assemble \
#  --tx-body-file matx.raw \
#  --witness-file matx.policy.witness \
#  --witness-file matx.pay.witness \
#  --out-file matx.signed

cardano-cli transaction sign \
	     --signing-key-file payment.skey \
	     --signing-key-file "policy-$1.skey" \
	     --script-file "policy-$1.script" \
	     --mainnet \
	     --tx-body-file matx.raw \
         --out-file matx.signed
