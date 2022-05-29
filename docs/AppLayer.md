# Context
Vessel takes a simplistic approach to file overlays.  Initially vessel only supported two "layers".  The base layer,
which is the freebsd base system and the modifications layer which makes changes to a clone of the base layer.  The problem
with this simplified approach is that many applications require gigabytes of changes to the base system.  A simple
django app that uses numpy requires the compression and transfer of multiple gigabytes of files when publishing to
a repo.  This is frustrating when trying to make a simple release.  It's terrifying when a hotfix is required and it
takes 15 minutes to publish and update the application container.  It's also very wasteful on space.

# Application Layer
The application layer is introduced to address the above issues.  The idea is that three layers will now be supported:

1. The base layer - Same as is currently supported.
2. The dependency layer - Uses the existing FROM command to specify the base layer
3. The application - Contains only the changes to the application

There are two options for implementing the application layer pattern:

1. *Simple Implementation*: Have a separate VesselFile per layer.  Don't introduce new commands, just introduce support
for deeper layers in ZFS.
2. *Batteries Included*: The application layer is a first class citizen and we modify commands and add new commands
that understand the application layer.

## MVP Proposal
The MVP for application layer will be the simple implementation.  Support will be added for 3 layers (potentially unlimited).

Details:

1. Every layer will have it's own VesselFile.
2. Layers will obviously need to be built before they are used.
3. From command will support multiple layers.  Example configuration layer that is above the app layer may look 
like: `FROM FREEBSD:13.0-RELEASE/RE-DEPS:1.2/RE:1.3`
4. Layers are separated with forward slash.
5. Layers to the right of the chain are not necessarily linked to layers on the left of the chain.  *NOTE* We'll do whatever is easiest here.  If it's easier to link them then we will.

### Required Changes for MVP

#### Build command

The build command interface doesn't change.  We will need to review how resolv.conf is updated during the build.
##### FROM file Command

* Don't assume that the image is a single image that can be pulled from FREEBSD.org
* The first image in the image chain could be first pulled from the repo but if it doesn't exist, it can be pulled from freebsd.org
* Write all parent images to the metadata db file.  There's already an array section for this.

#### Publish command

* Check if any of the chain of images exists before uploading
* If any of the images doesn't exist, upload the image

#### Pull command

* Pull all images in the chain that are not already imported and exist in the repo
* If any required images do not exist in the repo report an error.
* images must be imported in order

#### Run command

* The run command can be executed with the last piece of the image chain and tag.  The user should not be required to type the entire chain.

#### Image command

* The parent images displayed should be a comma separated list.
* removing a dependency image should fail until all images that depend on it are removed.  At some point we might consider adding a -R flag.

