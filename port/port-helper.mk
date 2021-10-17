# - Run from top level directory
# - Set DISTDIR=/tmp in environment
COMMIT!= git rev-parse HEAD
VERSION?=1.1.2-${COMMIT}
DISTDIR?=/tmp
STAGEDIR?=FBSD

distdir: .PHONY
	mkdir -p ${DISTDIR}

#ssteidl-FBSDAppContainers-1.0-894fa8fe51401e3c8e10bc67fe86a0e21a63e2ae_GH0.tar.gz
tarball: distdir 
	git archive -v --format tgz --prefix FBSDAppContainers-${COMMIT}/ -o ${DISTDIR}/ssteidl-FBSDAppContainers-${VERSION}_GH0.tar.gz ${COMMIT}
	make -C port makesum
