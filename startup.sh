#!/bin/bash

function print_help {
cat <<EOF
        Generic Postfix Setup Script
===============================================

to create a new postfix server for your domain
you should use the following commands:

  docker run -p 25:25 -v /maildirs:/var/mail \
         dockerimage/postfix \
         yourdomain.com \
         user1:password \
         user2:password \
         userN:password

this creates a new smtp server which listens
on port 25, stores mail under /mailsdirs
and has serveral user accounts like
user1 with password "password" and a mail
address user1@yourdomain.com
________________________________________________
by MarvAmBass
EOF
}

if [ "-h" == "$1" ] || [ "--help" == "$1" ] || [ -z $1 ] || [ "" == "$1" ]
then
  print_help
  exit 0
fi

if [ ! -f /etc/default/saslauthd ]
then
  >&2 echo ">> you're not inside a valid docker container"
  exit 1;
fi

echo ">> setting up postfix for: $1"

# add domain
postconf -e myhostname="$1"
#postconf -e mydestination="$1"
postconf -e mydestination="example.com"

postconf -e virtual_mailbox_domains="$1"
postconf -e 'virtual_mailbox_base = /var/vmail'
postconf -e 'virtual_mailbox_maps = hash:/etc/postfix/vmailbox'
postconf -e 'virtual_minimum_uid = 1000'
postconf -e 'virtual_uid_maps = static:5000'
postconf -e 'virtual_gid_maps = static:5000'

chown -R root:root /etc/postfix/vmailbox
chown -R vmail:vmail /var/vmail
chmod -R g+w /var/vmail
#postfix check <-docker-enter�œ����Ċm�F

postmap /etc/postfix/vmailbox

echo "$1" > /etc/mailname
echo "Domain $1" >> /etc/opendkim.conf


# DKIM
if [ -z ${DISABLE_DKIM+x} ]
then
  echo ">> enable DKIM support"
  
  if [ -z ${DKIM_CANONICALIZATION+x} ]
  then
    DKIM_CANONICALIZATION="simple"
  fi
  
  echo "Canonicalization $DKIM_CANONICALIZATION" >> /etc/opendkim.conf
  
  postconf -e milter_default_action="accept"
  postconf -e milter_protocol="2"
  postconf -e smtpd_milters="inet:localhost:8891"
  postconf -e non_smtpd_milters="inet:localhost:8891"
  
  # add dkim if necessary
  if [ ! -f /etc/postfix/dkim/dkim.key ]
  then
    echo ">> no dkim.key found - generate one..."
    opendkim-genkey -s mail -d $1
    mv mail.private /etc/postfix/dkim/dkim.key
    echo ">> printing out public dkim key:"
    cat mail.txt
    mv mail.txt /etc/postfix/dkim/dkim.public
    echo ">> please at this key to your DNS System"
  fi
  echo ">> change user and group of /etc/postfix/dkim/dkim.key to opendkim"
  chown opendkim:opendkim /etc/postfix/dkim/dkim.key
  chmod o=- /etc/postfix/dkim/dkim.key
fi

# add aliases
> /etc/aliases
if [ ! -z ${ALIASES+x} ]
then
  IFS=';' read -ra ADDR <<< "$ALIASES"
  for i in "${ADDR[@]}"; do
    echo "$i" >> /etc/aliases
    echo ">> adding $i to /etc/aliases"
  done
fi
echo ">> the new /etc/aliases file:"
cat /etc/aliases
newaliases

# starting services
echo ">> starting the services"
service rsyslog start

if [ -z ${DISABLE_DKIM+x} ]
then
  service opendkim start
fi

service saslauthd start
service postfix start

# print logs
echo ">> printing the logs"
touch /var/log/mail.log /var/log/mail.err /var/log/mail.warn
chmod a+rw /var/log/mail.*
#tail -F /var/log/mail.*





# Certificates
export CERTNAME=`hostname -f | sed 's/\./-/g'`
cp /certs/$CERTNAME.key /etc/ssl/private/dovecot.key
cp /certs/$CERTNAME.pem /etc/ssl/certs/dovecot.pem

#chown -R vmail:vmail /var/vmail
mkdir /var/mail/home
chown -R vmail:vmail /var/mail/home
chmod -R 777 /var/mail/home
#chmod -R 777 /var/mail
dovecot -F
