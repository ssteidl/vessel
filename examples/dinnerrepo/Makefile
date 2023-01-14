#Makefile to demonstrate how to use fossil for building, publishing and deploying
#images via an S3 image repository.

#Build the image.  Note that the '-E' flag is important for sudo so that
#the artifacts (image manifest) are created in the user's vessel directory and
#not root's.
.PHONY: build-image
build-image:
	sudo -E vessel build --file=./DinnerVesselFile --name=dinner --tag=1.0

#Runs the image using the .ini run configuration to mount the dataset so the
#fossil db is not removed when the container is destroyed.
.PHONY: run
run:
	sudo -E vessel run --ini=./deploydir/dinnerrepo.ini --rm dinner:1.0 -- sh /etc/rc

#Publish to s3.  Note that you need to set the VESSEL_REPO_URL environment variable.
#By default VESSEL_REPO_URL is the local filesystem.  s3cmd needs to be configured before
#publishing and pulling to s3
.PHONY: publish
publish:
	sudo -E env VESSEL_REPO_URL=s3://appc-test1 vessel publish --tag=1.0 dinner

#After publishing to S3, deploying is trivial as we just need to scp the run configuration
# file to our production server.  vessel-supervisor will see the file, pull and run the container.
.PHONY: deploy
deploy:
	scp ./deploydir/dinnerrepo.ini prod:/vessel/supervisor/deploy

.PHONY: clean
clean:
	sudo -E vessel image --rm dinner:1.0
