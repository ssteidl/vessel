#include <stdio.h>
#include <curl/curl.h>
 
#if !CURL_AT_LEAST_VERSION(7, 62, 0)
#error "this example requires curl 7.62.0 or later"
#endif
 
int main(void)
{
  CURLU *h;
  CURLUcode uc;
  char *host;
  char *path;
 
  h = curl_url(); /* get a handle to work with */ 
  if(!h)
    return 1;
 
  /* parse a full URL */ 
  uc = curl_url_set(h, CURLUPART_URL, "s3://example.com/path/index.html", CURLU_NON_SUPPORT_SCHEME);
  if(uc)
    goto fail;
 
  /* extract scheme name from the parsed URL */
  uc = curl_url_get(h, CURLUPART_SCHEME, &host, 0);
  if(!uc) {
    printf("Host name: %s\n", host);
    curl_free(host);
  }
 
  /* extract the path from the parsed URL */ 
  uc = curl_url_get(h, CURLUPART_PATH, &path, 0);
  if(!uc) {
    printf("Path: %s\n", path);
    curl_free(path);
  }
 
  /* redirect with a relative URL */ 
  uc = curl_url_set(h, CURLUPART_URL, "../another/second.html", 0);
  if(uc)
    goto fail;
 
  /* extract the new, updated path */ 
  uc = curl_url_get(h, CURLUPART_PATH, &path, 0);
  if(!uc) {
    printf("Path: %s\n", path);
    curl_free(path);
  }
 
  fail:
  curl_url_cleanup(h); /* free url handle */ 
  return 0;
}
