PORTNAME=	fbsdappc
DISTVERSION=	0.0
CATEGORIES=	sysutils

MAINTAINER=	ssteidley@gnsoftwarelabs.com
COMMENT=	FreeBSD specific container manager

LICENSE=	PD

USES=		cmake:noninja

USE_GITHUB=	yes
GH_ACCOUNT=	ssteidl
GH_PROJECT=	FBSDAppContainers
GH_TAGNAME=	97c3f849303eb643ddb47759fa98e9c9ee021097

LIB_DEPENDS+=	libcurl.so:ftp/curl libtcl86.so:lang/tcl86
#MAKE_ENV=	CC="cc"

# USE_RC_SUBR=	${PORTNAME}

# post-install:
# 	${MV} ${STAGEDIR}${ETCDIR}/${PORTNAME}.conf ${STAGEDIR}${ETCDIR}/${PORTNAME}.conf.sample
# 	${MV} ${STAGEDIR}${ETCDIR}/parsers.conf ${STAGEDIR}${ETCDIR}/parsers.conf.sample

.include <bsd.port.mk>
