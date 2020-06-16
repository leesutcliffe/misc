#!/bin/sh

function buildInstalledCertsArray {
    tmsh save sys config partitions all
    tmsh list sys file ssl-cert |  awk '/crt/ {print $4}' | sed '/^[[:space:]]*$/d' > /var/tmp/installedCerts.tmp

    # iterate over tmp file to create array of used certificates
    while read line; do
        for i in "${!ignoreCerts[@]}"; do
            if [[ $line = ${ignoreCerts[$i]} ]]; then
                ignore="true"
            else
                if [[ $ignore != "true" ]];then
                    ignore=""
                else
                    # do not add cert to array if already added
                    if [[ ! " ${instCertsArr[@]} " =~ " ${line} " ]]; then
                        instCertsArr+=("$line")
                    fi
                fi
            fi
        done
    done </var/tmp/installedCerts.tmp
    rm /var/tmp/installedCerts.tmp
}

function buildDeleteCertsArray {
    # populate deleteCerts array
    for cert in "${instCertsArr[@]}"; do
        isUsed=$(grep $cert /config/bigip.conf /config/partitions/*/bigip.conf | grep -v -e "sys file ssl-cert" -e cache-path)
        if [ -z "$isUsed" ];then
            deleteCerts+=("$cert")
        fi
    done
}

function buildDeleteKeysArray {
    # delete any associated keys
    for cert in "${deleteCerts[@]}"; do
        hasKey=$(tmsh list sys file ssl-key ${cert%.*}.key > /dev/null 2>&1)
        if ! [ -z "$hasKey" ];then
            deleteKeys+=("${cert%.*}.key")
        fi
    done
}

function deleteUnusedCerts {

    if [ ${#deleteCerts[@]} -eq 0 ]; then
        echo "-------------------------------------------------------------------------"
        echo "There are no unused certificates to delete, existing"
        echo "-------------------------------------------------------------------------"
        exit 0
    else
        echo "-------------------------------------------------------------------------"
        echo "The following keys are not in use can can be deleted:"
        for cert in "${deleteCerts[@]}"; do
            echo "   ${cert}"
        done
        echo "-------------------------------------------------------------------------"
        read -p "would you like to delete these unused certificates? (y/n)?" answer
        case ${answer:0:1} in
            y|Y )
                createUcsArchive
                echo "-------------------------------------------------------------------------"
                echo "deleting certs..."
                for cert in "${deleteCerts[@]}"; do
                    delete sys file ssl-key $cert
                    echo "    $cert"
                done

                if [ ${#deleteKeys[@]} -eq 0 ]; then
                echo "-------------------------------------------------------------------------"
                    echo "no associated keys to delete, exiting"
                    exit 0
                else
                    echo "-------------------------------------------------------------------------"
                    echo "deleting keys..."
                    for key in "${deleteKeys[@]}"; do
                        delete sys file ssl-key $cert
                        echo "$key"
                        exit 0
                    done
                fi
                ;;
            * )
                exit 0
                ;;
        esac
    fi
}

function createUcsArchive {
    echo
    today=`date +%Y-%m-%d.%H.%M.%S`
    echo "Creating UCS archive auto.${today}.ucs"
    tmsh save sys ucs ${today}.ucs
}

# initialise vars
instCertsArr=()
deleteCerts=()

# ignore certs defined here - f5-irile.crt is used to sign F5 iRules
ignoreCerts=("f5-irule.crt" "ca-bundle.crt")

# build installed certificates array - excluding certs to ignore
buildInstalledCertsArray

# check if installed certs are used in bigip.conf (including partitions) - ltm sys files are exluded from results
buildDeleteCertsArray

# build list of associated keys (not all certs will have keys)
buildDeleteKeysArray

# optionally delete unused certs
deleteUnusedCerts
