#
# Little AWK script to extract the HTTP body from the output of curl -i -
# which may contain intermediate status info for connecting to the proxy or whatever - ex:
#
# HTTP/1.1 200 OK
#
BEGIN {
  status="unknown";
  lastlineblank="true";
}; 
(lastlineblank=="true" && $1 !~ /^HTTP/ && $0 !~ /^[\r\n\s]*$/) { body="true"; };
(lastlineblank=="true" && $1 ~ /^HTTP/) { status=$2; };
(lastlineblank="true" && $0 !~ /^[\r\n\s]*$/) { lastlineblank="false" };
(body != "true" && /^[\r\n\s]*$/) { lastlineblank="true" };
body=="true" { print status; exit 0 }
