#ifndef IMAGE_ARCHIVE_H
#define IMAGE_ARCHIVE_H

namespace appc
{

class fs_path;
/**
 * The term image_archive represents an image that can
 * be stored or retrieved from a registry.  image_archives are
 * somehow packaged so that they can be transported and stored
 * in an archive.  That package could theoretically be a
 * tarball, iso9660 image, ufs image, zfs snapshot etc.
 */

int create_image_archive(const fs_path& source, const fs_path& dest);

}
#endif // IMAGE_ARCHIVE_H
