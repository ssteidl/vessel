PORTNAME=	vessel
DISTVERSION=	1.1.2
CATEGORIES=	sysutils

MAINTAINER=	ssteidley@gnsoftwarelabs.com
COMMENT=	FreeBSD specific container manager

LICENSE=	PD

USES=		cmake:noninja

USE_GITHUB=	yes
GH_ACCOUNT=	ssteidl
GH_PROJECT=	FBSDAppContainers
GH_TAGNAME!=	git rev-parse HEAD

LIB_DEPENDS+=	libcurl.so:ftp/curl libtcl86.so:lang/tcl86 
RUN_DEPENDS+=   zip:archivers/zip tcllib>=1.2:devel/tcllib s3cmd:net/py-s3cmd
#MAKE_ENV=	CC="cc"

# USE_RC_SUBR=	${PORTNAME}

# post-install:
# 	${MV} ${STAGEDIR}${ETCDIR}/${PORTNAME}.conf ${STAGEDIR}${ETCDIR}/${PORTNAME}.conf.sample
# 	${MV} ${STAGEDIR}${ETCDIR}/parsers.conf ${STAGEDIR}${ETCDIR}/parsers.conf.sample

.include <bsd.port.mk>
