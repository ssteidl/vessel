# - Run from top level directory
# - Set DISTDIR=/tmp in environment
COMMIT!= git rev-parse HEAD
VERSION?=1.2.0-${COMMIT}
DISTDIR?=/tmp
STAGEDIR?=FBSD

distdir: .PHONY
	mkdir -p ${DISTDIR}

#ssteidl-vessel-1.0-894fa8fe51401e3c8e10bc67fe86a0e21a63e2ae_GH0.tar.gz
tarball: distdir 
	git archive -v --format tgz --prefix vessel-${COMMIT}/ -o ${DISTDIR}/ssteidl-vessel-${VERSION}_GH0.tar.gz ${COMMIT}
	make -C port makesum
