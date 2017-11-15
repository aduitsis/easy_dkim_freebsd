

ETC=		/usr/local/etc/mail
CONF=		${ETC}/opendkim.conf
SELECTOR=	dkim000
DOMAIN=		whatever
RUN=		/var/run/dkim
DB=		/var/db/dkim
KEYDIR=		${DB}/${DOMAIN}
KEYFILE=	${KEYDIR}/${SELECTOR}.txt
USER=		mailnull
GROUP=		mailnull
USERGROUP=	${USER}:${GROUP}
KEYTABLE=	${ETC}/opendkim.keytable
SIGNTABLE=	${ETC}/opendkim.signingtable
PRIVATE=	${DB}/${DOMAIN}/${SELECTOR}.private

RR=		${SELECTOR}._domainkey.${DOMAIN}
KEYTABLEENTRY=	"${RR}      ${DOMAIN}:${SELECTOR}:${PRIVATE}"
SIGNTABLEENTRY=	"*@${DOMAIN}      ${RR}"

packages:
	echo ${DATE}
	pkg info -q opendkim || pkg install -y opendkim


opendkim_conf:
	touch ${CONF}
	
	echo Canonicalization	relaxed/simple				>  ${CONF}.candidate
	echo Mode		s					>> ${CONF}.candidate
	echo Socket             local:/var/run/dkim/opendkim.sock	>> ${CONF}.candidate
	echo KeyTable           refile:${KEYTABLE}			>> ${CONF}.candidate
	echo SigningTable       refile:${SIGNTABLE}			>> ${CONF}.candidate
	echo Syslog	        Yes					>> ${CONF}.candidate
	echo LogWhy		Yes					>> ${CONF}.candidate
	echo SyslogSuccess      Yes					>> ${CONF}.candidate
	echo UserID             ${USERGROUP}				>> ${CONF}.candidate
	- diff -q ${CONF} ${CONF}.candidate || ( mv ${CONF} ${CONF}.old && mv ${CONF}.candidate ${CONF} )

conf: packages opendkim_conf
	touch ${ETC}/opendkim.keytable
	touch ${ETC}/opendkim.signingtable
	mkdir -p ${RUN} ${DB}
	chown ${USERGROUP} ${RUN} ${DB}
	chmod 0700 ${RUN}

enable: conf
	sysrc milteropendkim_enable="YES"
	sysrc milteropendkim_uid="mailnull"
	sysrc milteropendkim_cfgfile="${CONF}"


domain:
.if exists(${KEYFILE})
	@echo ${KEYFILE} exists:
.else
	@echo Generating DKIM file ${KEYFILE}
	mkdir -p ${KEYDIR}
	opendkim-genkey -a -b 2048 -d ${DOMAIN} -D ${KEYDIR} -s ${SELECTOR}
	chown ${USERGROUP} ${KEYFILE}
.endif
	@cat ${KEYFILE}

	
update_keytable: domain
	egrep -q '^${RR} ' ${KEYTABLE} || echo ${KEYTABLEENTRY}  >> ${KEYTABLE}
	egrep -q '^\*\@${DOMAIN} ' ${SIGNTABLE} || echo ${SIGNTABLEENTRY} >> ${SIGNTABLE}

all: conf enable update_keytable

