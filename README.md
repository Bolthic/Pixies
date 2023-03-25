# Pixies

A simple script to create ssl certificate.

Inspired from

- <https://pki-tutorial.readthedocs.io/en/latest/simple/index.html>

Other links:

- <https://www.digicert.com/kb/ssl-support/openssl-quick-reference-guide.htm>
- <https://www.digitalocean.com/community/tutorials/openssl-essentials-working-with-ssl-certificates-private-keys-and-csrs>

## Configure

edit pixies.sh or define those environnement variable

```` shell
####################################
# root for all authority
####################################
PIXIES_HOME="${PIXIES_HOME:-"./pki"}"
````

Personalize your certificate
```` shell
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
````

Personalize the root authority openssl configuration
```` shell
####################################
# root authority
####################################
# configuration file of root authority
PIXIES_ROOT_CNF="${PIXIES_ROOT_CNF:-"./pixies.ca.cnf"}"
# root authority directory
PIXIES_ROOTCA="${PIXIES_HOME}/ca"
````

Personalize the both intermediate authority openssl configuration
```` shell
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
````

## Initialize


```` shell
pixies.sh server monserver.fr www.monserver.fr
````

```` shell
pixies.sh use moi
````