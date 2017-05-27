FROM ubuntu:14.04
MAINTAINER MarvAmBass

## Install Postfix.

# pre config
RUN echo mail > /etc/hostname; \
    echo "postfix postfix/main_mailer_type string Internet site" > preseed.txt; \
    echo "postfix postfix/mailname string mail.example.com" >> preseed.txt

# load pre config for apt
RUN debconf-set-selections preseed.txt

# install
RUN apt-get update; apt-get install -y \
    postfix \
    opendkim \
    mailutils \
    opendkim-tools \
    sasl2-bin \
    supervisor \
    dovecot-core \
    dovecot-imapd \
    dovecot-pop3d \
    dovecot-lmtpd \
    dovecot-sieve

## Configure Postfix

#RUN postconf -e smtpd_banner="\$myhostname ESMTP"; \
#    postconf -e mail_spool_directory="/var/spool/mail/"; \
#    postconf -e mailbox_command=""

## Configure Sasl2

# config
RUN sed -i 's/^START=.*/START=yes/g' /etc/default/saslauthd; \
    sed -i 's/^MECHANISMS=.*/MECHANISMS="shadow"/g' /etc/default/saslauthd

RUN echo "pwcheck_method: saslauthd" > /etc/postfix/sasl/smtpd.conf; \
    echo "mech_list: PLAIN LOGIN" >> /etc/postfix/sasl/smtpd.conf; \
    echo "saslauthd_path: /var/run/saslauthd/mux" >> /etc/postfix/sasl/smtpd.conf

# postfix settings
RUN postconf -e smtpd_sasl_auth_enable="yes"; \
    postconf -e smtpd_recipient_restrictions="permit_mynetworks permit_sasl_authenticated reject_unauth_destination"; \
    postconf -e smtpd_helo_restrictions="permit_sasl_authenticated, permit_mynetworks, reject_invalid_hostname, reject_unauth_pipelining, reject_non_fqdn_hostname"

RUN sed -i "s/#submission inet n/submission inet n       -       -       -       -       smtpd\n20000 inet n/" /etc/postfix/master.cf; \ 
    sed -i "s/#  -o smtpd_sasl_auth_enable=yes/  -o smtpd_sasl_auth_enable=yes/" /etc/postfix/master.cf; \
    sed -i "s/#  -o smtpd_client_restrictions=\$mua_client_restrictions/  -o smtpd_client_restrictions=permit_sasl_authenticated,reject/" /etc/postfix/master.cf

# add user postfix to sasl group
RUN adduser postfix sasl

# chroot saslauthd fix
RUN sed -i 's/^OPTIONS=/#OPTIONS=/g' /etc/default/saslauthd; \
    echo 'OPTIONS="-c -m /var/spool/postfix/var/run/saslauthd"' >> /etc/default/saslauthd

# dkim settings
RUN mkdir -p /etc/postfix/dkim; \
    echo "KeyFile                 /etc/postfix/dkim/dkim.key" >> /etc/opendkim.conf; \
    echo "Selector                mail" >> /etc/opendkim.conf; \
    echo "SOCKET                  inet:8891@localhost" >> /etc/opendkim.conf

RUN sed -i 's/^SOCKET=/#SOCKET=/g' /etc/default/opendkim; \
    echo 'SOCKET="inet:8891@localhost"' >> /etc/default/opendkim

## FINISHED






RUN groupadd -g 5000 vmail && useradd -u 5000 -g vmail vmail

RUN rm -rf /etc/dovecot
ADD dovecot /etc/dovecot

RUN sievec /etc/dovecot/sieve-before/
RUN sievec /etc/dovecot/sieve-after/

VOLUME ["/var/vmail"]
#VOLUME ["/etc/dovecot/passwd"]







# Postfix Ports
EXPOSE 25

# SASL
EXPOSE 12345
# IMAP
EXPOSE 143
# IMAPS
EXPOSE 993
# LMTP
EXPOSE 24

# Add startup script
ADD startup.sh /opt/startup.sh
RUN chmod a+x /opt/startup.sh

# Docker startup
ENTRYPOINT ["/opt/startup.sh"]
CMD ["-h"]


#docker stop postfix1; docker rm postfix1; sudo rm -rf /home/core/maildir/; docker build -t docker-versatile-postfix:1.0 .
#docker run -d -p 25:25 -p 587:587 -p 110:110 -p 995:995 -p 143:143 -p 993:993 -v /home/core/docker-versatile-postfix/dov_certs2:/certs   -v /home/core/maildir:/var/vmail -v /home/core/docker-versatile-postfix/dov_certs2/passwd:/etc/dovecot/passwd   -h iseisaku.com -v /home/core/docker-versatile-postfix/vmailbox:/etc/postfix/vmailbox -v /dkim:/etc/postfix/dkim/ -e 'ALIASES=postmaster:root;hostmaster:root;webmaster:root' --name postfix1 docker-versatile-postfix:1.0 iseisaku.com webmaster:oohana user1:oohana
