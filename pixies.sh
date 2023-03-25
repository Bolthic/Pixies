#/bin/bash

####################################
# root for all authority
####################################
PIXIES_HOME="${PIXIES_HOME:-"./pki"}"

####################################
# Subject customization
####################################
PIXIES_COUNTRY="${PIXIES_COUNTRY:-"FR"}"
PIXIES_STATE="${PIXIES_STATE:-"IDF"}"
PIXIES_LOCALITY="${PIXIES_LOCALITY:-"Paris"}"
PIXIES_ORGANISATION="${PIXIES_ORGANISATION:-"TownHall Services"}"
PIXIES_ROOT_UNIT="${PIXIES_ROOT_UNIT:-"Kitchen"}"
PIXIES_SERVERS_UNIT="${PIXIES_SERVERS_UNIT:-"Camp"}"
PIXIES_USERS_UNIT="${PIXIES_USERS_UNIT:-"Jail"}"

####################################
# root authority
####################################
# configuration file of root authority
PIXIES_ROOT_CNF="${PIXIES_ROOT_CNF:-"./pixies.ca.cnf"}"
# root authority directory
PIXIES_ROOTCA="${PIXIES_HOME}/ca"


####################################
# intermediate authority
####################################
# configuration file of intermediate authority
# this file will be used to create both servers and users authority if missing
PIXIES_IT_CNF=${PIXIES_IT_CNF:-"./pixies.it.cnf"}

# servers authority directory
PIXIES_SERVERS="${PIXIES_HOME}/servers"
# configuration file of servers intermediate authority
PIXIES_SERVERS_CNF=${PIXIES_SERVERS_CNF:-"$PIXIES_SERVERS/pixies.it.cnf"}

# users authority directory
PIXIES_USERS="${PIXIES_HOME}/users"
# configuration file of users intermediate authority
PIXIES_USERS_CNF=${PIXIES_USERS_CNF:-"$PIXIES_USERS/pixies.it.cnf"}




####################################
# Do not change those
PIXIES_ROOT_CERT="$PIXIES_ROOTCA/certs/ca.cert.pem"
PIXIES_SERVERS_CERT="$PIXIES_SERVERS/certs/intermediate.cert.pem"
PIXIES_USERS_CERT="$PIXIES_USERS/certs/intermediate.cert.pem"

function pixies_usage () {
    echo "Usage $0 <mode> [options]"
    echo "    init: initialize root ca"
    echo "    user: create a user certificate"
    echo "      <user_name> [<user_email>]"
    echo "    server: create a server certificate"
    echo "      <server_name> [<altName>]"
    echo "    check: check validity of all known cert"
    echo
}


function pixies_init () {
    # adapt openssl config files
    sed -i "s+dir               = .*+dir               = $PIXIES_ROOTCA+g" pixies.ca.cnf

    # directory structures
    for i in "${PIXIES_ROOTCA}" "${PIXIES_SERVERS}" "${PIXIES_USERS}"
    do
        mkdir -p "${i}"/{certs,csr,crl,newcerts,private}
        chmod 700 "${i}"/private
        if [ ! -e "${i}/index.txt" ]; then
            touch "${i}/index.txt"
        fi
        if [ ! -e "${i}/serial" ]; then
            echo "1000" > "${i}/serial"
        fi
    done
    if [ ! -e $PIXIES_SERVERS_CNF ]; then
        cp $PIXIES_IT_CNF $PIXIES_SERVERS_CNF
    fi
    if [ ! -e $PIXIES_USERS_CNF ]; then
        cp $PIXIES_IT_CNF $PIXIES_USERS_CNF
    fi
    sed -i "s+dir               = .*+dir               = $PIXIES_SERVERS+g" $PIXIES_SERVERS_CNF 
    sed -i "s+dir               = .*+dir               = $PIXIES_USERS+g" $PIXIES_USERS_CNF 
}

function pixies_subject () {
    #ex: "/C=US/ST=Utah/L=Lehi/O=Your Company, Inc./OU=IT/CN=yourdomain.com"
    echo "/C=$PIXIES_COUNTRY/ST=$PIXIES_STATE/L=$PIXIES_LOCALITY/O=$PIXIES_ORGANISATION/OU=$2/CN=$1"
}

function pixies_isvalid () {
    certName="$1"
    cert="$2"
    kind="$3"
    if [ -e $PIXIES_ROOT_CERT ]; then
        if [ -e $cert ]; then
            dates=`openssl x509 -in "$cert" -noout -enddate | cut -d= -f2`
            case "$kind" in
                server)
                    if openssl verify -CAfile "$PIXIES_ROOT_CERT" -untrusted "$PIXIES_SERVERS_CERT" "$cert" >/dev/null; then
                        true
                    else
                        echo "$certName: $cert does not verify: end date is $dates"
                        return 3
                    fi
                    ;;
                user)
                    if openssl verify -CAfile "$PIXIES_ROOT_CERT" -untrusted "$PIXIES_USERS_CERT"  "$cert" >/dev/null; then
                        true
                    else
                        echo "$certName: $cert does not verify: end date is $dates"
                        return 3
                    fi
                    ;;
                *)
                    if openssl verify -CAfile "$PIXIES_ROOT_CERT" "$cert" >/dev/null; then
                        true
                    else
                        echo "$certName: $cert does not verify: end date is $dates"
                        return 3
                    fi
                    ;;
            esac
            if openssl x509 -in "$cert" -noout -checkend 0 >/dev/null; then
                echo "$certName: $cert is valid until $dates"
                return 0
            else
                echo "$certName: $cert is expired since $dates"
                return 2
            fi
        else
            echo "$certName: $cert missing"
            return 1
        fi
    else
        echo "$certName: RootCertificate is missing"
        return 4
    fi
}

function pixies_check_all(){
    pixies_isvalid "Root   " "$PIXIES_ROOT_CERT"
    pixies_isvalid "Servers" "$PIXIES_SERVERS_CERT"
    for i in `ls $PIXIES_SERVERS/certs | grep cert.pem | grep -v intermediate.cert.pem`; do
        pixies_isvalid "       " "$PIXIES_SERVERS/certs/$i" "server"
    done
    pixies_isvalid "Users  " "$PIXIES_USERS_CERT"
    for i in `ls $PIXIES_USERS/certs | grep cert.pem | grep -v intermediate.cert.pem`; do
        pixies_isvalid "       " "$PIXIES_USERS/certs/$i" "user"
    done
}


function pixies_generate_ca () {
    subj="$(pixies_subject root $PIXIES_ROOT_UNIT)"
    # generate root ca
    if [ -e "$PIXIES_ROOTCA/private/ca.key.pem" ]; then
        echo "root ... private key ok"
    else
        echo "root ... generating private key"
        #openssl genrsa -aes256 -out "$PIXIES_ROOTCA/private/ca.key.pem" 2048
        openssl req -new -newkey rsa:2048 -nodes \
            -subj "$subj" -config "$PIXIES_ROOT_CNF" \
            -keyout "$PIXIES_ROOTCA/private/ca.key.pem" \
            -out "$PIXIES_ROOTCA/certs/ca.req.pem" && \
        chmod 0400 "$PIXIES_ROOTCA/private/ca.key.pem" || return 1
    fi

    if [ ! -e "$PIXIES_ROOTCA/certs/ca.cert.pem" -o "$PIXIES_ROOTCA/private/ca.key.pem" -nt "$PIXIES_ROOTCA/certs/ca.cert.pem" ]; then
        echo "root ... self signing certificate"
        # openssl req -new -x509 -days 10958 -sha256 -extensions v3_ca \
        #         -subj = "$subj" -config "$PIXIES_ROOT_CNF" \
        #         -key $PIXIES_ROOTCA/private/ca.key.pem \
        #         -out $PIXIES_ROOTCA/certs/ca.cert.pem
        openssl ca -create_serial -days 10958 -selfsign -extensions v3_ca \
                -notext -md sha256 -subj "$subj" -config "$PIXIES_ROOT_CNF" \
                -keyfile "$PIXIES_ROOTCA/private/ca.key.pem" \
                -in "$PIXIES_ROOTCA/certs/ca.req.pem" \
                -out "$PIXIES_ROOTCA/certs/ca.cert.pem" || return 1
    else
        echo "root ... certificate ok"
    fi
    return 0
}

function pixies_generate_intermediate () {
    NAME="$1"
    case $NAME in
        server)
            UNIT="$PIXIES_SERVERS_UNIT"
            DIR="$PIXIES_SERVERS"
            CNF="$PIXIES_SERVERS_CNF"
            ;;
        user)
            UNIT="$PIXIES_USERS_UNIT"
            DIR="$PIXIES_USERS"
            CNF="$PIXIES_USERS_CNF"
            ;;
        *)
            echo "Could not generate intermediate for unknown role $NAME"
            return 1
            ;;
    esac

    subj="$(pixies_subject $NAME $UNIT)"
    # generate intermediate ca
    if [ -e "$DIR/private/intermediate.key.pem" ]; then
        echo "$NAME ... private key ok"
    else
        echo "$NAME ... generating private key"
        #openssl genrsa -aes256 -out "$DIR/private/$NAME.key.pem" 2048
        openssl req -new -newkey rsa:2048 -nodes \
            -subj "$subj" -config "$CNF" \
            -keyout "$DIR/private/intermediate.key.pem" \
            -out "$DIR/certs/intermediate.req.pem" && \
        chmod 0400 "$DIR/private/intermediate.key.pem" || return 1
        rm -f "$DIR/certs/intermediate.req.pem"
    fi

    if [ ! -e "$DIR/csr/intermediate.csr.pem" -o "$DIR/private/intermediate.key.pem" -nt "$DIR/csr/intermediate.csr.pem" ]; then
        echo "$NAME ... create the certificate"
        openssl req -new -sha256 -subj "$subj" -config "$CNF" \
                -key $DIR/private/intermediate.key.pem \
                -out $DIR/csr/intermediate.csr.pem || return 1
    fi

    if [ ! -e "$DIR/certs/intermediate.cert.pem" -o "$DIR/csr/intermediate.csr.pem" -nt "$DIR/certs/intermediate.cert.pem" ]; then
        echo "$NAME ... signing the certificate"
        openssl ca -config $PIXIES_ROOT_CNF \
            -extensions v3_intermediate_ca -days 3650 -notext -md sha256 \
            -in "$DIR/csr/intermediate.csr.pem" \
            -out $DIR/certs/intermediate.cert.pem || return 1
    else
        echo "$NAME ... certificate ok"
    fi

    if [ ! -e "$DIR/certs/ca-chain.cert.pem" -o "$DIR/certs/intermediate.cert.pem" -nt "$DIR/certs/ca-chain.cert.pem" ]; then
        echo "$NAME ... generate the ca-chain.cert.pem"
        cat $DIR/certs/intermediate.cert.pem $PIXIES_ROOT_CERT > $DIR/certs/ca-chain.cert.pem
        chmod 444 $DIR/certs/ca-chain.cert.pem || return 1
    else
        echo "$NAME ... ca-chain ok"
    fi
    return 0
}

function pixies_generate_user () {
    user="$1"
    if [ -z "$user" ]; then
        echo "Usage $0  user <user_name>"
        exit 1
    fi
    subj="$(pixies_subject $user $PIXIES_USERS_UNIT)"

    rm -rf "$PIXIES_USERS/private/u_${user}.key.pem" \
           "$PIXIES_USERS/csr/u_${user}.csr.pem" \
           "$PIXIES_USERS/certs/u_${user}.cert.pem"

    echo "u_$user ... generating private key" && \
    openssl req -new -newkey rsa:2048 -nodes -subj "$subj" \
            -keyout "$PIXIES_USERS/private/u_${user}.key.pem" \
            -out "$PIXIES_USERS/csr/u_${user}.csr.pem" && \
    chmod 0400 "$PIXIES_USERS/private/u_${user}.key.pem" && \
    echo "" && \
    echo "u_$user ...  sign cert" && \
    openssl ca -config "$PIXIES_USERS_CNF" \
            -extensions usr_cert -days 365 -notext -md sha256 \
            -in "$PIXIES_USERS/csr/u_${user}.csr.pem" \
            -out "$PIXIES_USERS/certs/u_${user}.cert.pem"
    chmod 0444 "$PIXIES_USERS/certs/u_${user}.cert.pem" && \
    echo "" && \
    echo "u_$user ... assemble p12" && \
    openssl pkcs12 -export -certfile "$PIXIES_USERS_CERT" \
            -inkey "$PIXIES_USERS/private/u_${user}.key.pem" \
            -in "$PIXIES_USERS/certs/u_${user}.cert.pem" \
            -out "$PIXIES_USERS/certs/u_${user}.p12" 

    pixies_isvalid "$user" "$PIXIES_USERS/certs/u_${user}.cert.pem" "user"

    # echo "u_$user ... request csr" && \
    # openssl req -new -sha256 -subj "$subj" -config "$PIXIES_USERS_CNF" \
    #         -key "$PIXIES_USERS/certs/u_${user}.key.pem" \
    #         -out "$PIXIES_USERS/csr/u_${user}.csr.pem" && \
    # echo "" && \

}


function pixies_generate_server () {
    server="$1"
    altName="$2"
    if [ -z "$server" ]; then
        echo "Usage $0 server <server_name> [<altName>]"
        exit 1
    fi
    if [ -z "$altName" ]; then
        altName="$server"
    fi
    subj="$(pixies_subject $server $PIXIES_SERVERS_UNIT)"

    rm -rf "$PIXIES_SERVERS/private/s_${server}.key.pem" \
           "$PIXIES_SERVERS/csr/s_${server}.csr.pem" \
           "$PIXIES_SERVERS/certs/s_${server}.cert.pem"

    echo "s_$server ... generating private key" && \
    openssl req -new -newkey rsa:2048 -nodes \
            -subj "$subj" -addext "subjectAltName=DNS:${altName}" \
            -keyout "$PIXIES_SERVERS/private/s_${server}.key.pem" \
            -out "$PIXIES_SERVERS/csr/s_${server}.csr.pem" && \
    chmod 0400 "$PIXIES_SERVERS/private/s_${server}.key.pem" && \
    echo "" && \
    echo "s_$server ...  sign cert" && \
    openssl ca -config "$PIXIES_SERVERS_CNF" \
            -extensions server_cert -days 365 -notext -md sha256 \
            -in "$PIXIES_SERVERS/csr/s_${server}.csr.pem" \
            -out "$PIXIES_SERVERS/certs/s_${server}.cert.pem" && \
    chmod 0444 "$PIXIES_SERVERS/certs/s_${server}.cert.pem" 

    pixies_isvalid "$server" "$PIXIES_SERVERS/certs/s_${server}.cert.pem" "server"

}

function pixies_display_cert(){
    #openssl x509 -noout -subject -issuer -dates -fingerprint -in "$1"
    openssl x509 -noout -text -in "$1"
}


pixies_init
mode="$1"
case "$mode" in
    init)
        pixies_generate_ca
        ;;
    check)
        pixies_check_all
        ;;
    user)
        pixies_generate_ca && \
        pixies_generate_intermediate "user" && \
        pixies_generate_user "$2" "$3"
        ;;
    server)
        pixies_generate_ca && \
        pixies_generate_intermediate "server" && \
        pixies_generate_server "$2" "$3"
        ;;  
    *)
        pixies_usage
        ;;
esac
