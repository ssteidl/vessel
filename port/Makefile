PORTNAME=	vessel
DISTVERSION=	1.2.1
CATEGORIES=	sysutils

MAINTAINER=	shane@zeta.investments
COMMENT=	FreeBSD specific container manager

LICENSE=	PD

USES=		cmake:noninja

USE_GITHUB=	yes
GH_ACCOUNT=	ssteidl
GH_PROJECT=	vessel
GH_TAGNAME!=	git rev-parse HEAD

LIB_DEPENDS+=	libcurl.so:ftp/curl libtcl86.so:lang/tcl86
RUN_DEPENDS+=   zip:archivers/zip tcllib>=1.2:devel/tcllib s3cmd:net/py-s3cmd@${PY_FLAVOR} tclsyslog>=2.1:sysutils/tclsyslog

.include <bsd.port.mk>
