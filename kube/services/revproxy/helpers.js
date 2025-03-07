/**
 * This is a helper script used in the reverse proxy
 * Note that this is not technically javascript, but nginscript (or njs)
 * See here for info: 
 *    - http://nginx.org/en/docs/njs/
 *    - https://www.nginx.com/blog/introduction-nginscript/
 */

/** global supporting atob polyfill below */
var chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';
// default threshold for assigning a service to production
// e.g. weight of 0 would mean all services are assigned to production
var DEFAULT_WEIGHT = 0;

/**
 * base64 decode polyfill from
 *     https://github.com/davidchambers/Base64.js/blob/master/base64.js
 */
function atob(input) {
  var str = String(input).replace(/[=]+$/, ''); // #31: ExtendScript bad parse of /=
  if (str.length % 4 == 1) {
    return input;
  }
  for (
    // initialize result and counters
    var bc = 0, bs, buffer, idx = 0, output = '';
    // get next character
    buffer = str.charAt(idx++);
    // character found in table? initialize bit storage and add its ascii value;
    ~buffer && (bs = bc % 4 ? bs * 64 + buffer : buffer,
      // and if not first of each 4 characters,
      // convert the first 8 bits to one ascii character
    bc++ % 4) ? output += String.fromCharCode(255 & bs >> (-2 * bc & 6)) : 0
  ) {
    // try to find character in table (0-63, not found => -1)
    buffer = chars.indexOf(buffer);
  }
  return output;
}



/**
 * nginscript helper for parsing user out of JWT tokens.
 * We appear to have access to the 'access_token' variable
 * defined in nginx.conf when this function runs via 'js_set'.
 * see https://www.nginx.com/blog/introduction-nginscript/
 *
 * @param {*} req
 * @param {*} res
 */
function userid(req, res) {
  var token = req.variables["access_token"];
  var user = "uid:null,unknown@unknown";

  if (token) {
    // note - raw token is secret, so do not expose in userid
    var raw = atob((token.split('.')[1] || "").replace('-', '+').replace('_', '/'));
    if (raw) {
      try {
        var data = JSON.parse(raw);
        if (data) {
          if (data.context && data.context.user && data.context.user.name) {
            user = "uid:" + data.sub + "," + data.context.user.name;
          }
        }
      } catch (err) {}
    }
  }
  return user;
}

/**
 * returns absolute value of a number
 */
function MathAbs(x) {
  x = +x;
  return (x > 0) ? x : 0 - x;
}

/**
 * util for hashing a string into given range
 * Source: http://pmav.eu/stuff/javascript-hashing-functions/source.html
 *
 * @param s - string to hash
 */
function simpleHash(s) {
  var i, hash = 0;
  for (i = 0; i < s.length; i++) {
    hash += (s[i].charCodeAt() * (i+1));
  }
  // mod 100 b/c we want a percentage range (ie 0-99)
  return MathAbs(hash) % 100;
}

/**
 * Returns a release (string) depending on the given
 * values provided
 *
 * @param hash_res - an integer to compare to service_weight
 * @param service_weight - integer threshold for assigning release as 'production'
 * @param default_weight - if service_weight is undefined, compare hash to this value
 * @returns {string} - release
 */
function selectRelease(hash_res, w) {
  // determine release by comparing hash val to service weight
  if (hash_res < parseInt(w)) {
    return 'canary';
  }
  return 'production';
}

function getWeight(service, weights) {
  if (typeof weights[service] === 'undefined') {
    return weights['default'];
  }
  return weights[service];
}

function releasesObjToString(releases) {
  var res = '';
  for (var service in releases) {
    if (releases.hasOwnProperty(service)) {
      res = res + service + '.' + releases[service] + '&';
    }
  }
  return res;
}

/**
 * Checks cookie (dev_canaries or service_releases) 
 * for service release versions and assigns
 * release versions for services not in the cookie based
 * on hash value and the percent weight of the canary.
 * If the weight for a service is 0, it ignores the cookie
 * and sets the release to production.
 * 
 * @param req - nginx request object
 * @return a string of service assignments. E.g:
 *   "fence.canary&sheepdog.production&"
 */
function getServiceReleases(req) {
  //
  // client cookie containing releases
  // developer override can force canary even when canary has
  // been deployed for general users by setting the canary weights to zero
  //
  var devOverride= !!req.variables['cookie_dev_canaries'];
  var release_cookie = req.variables['cookie_dev_canaries'] || req.variables['cookie_service_releases'] || '';
  // services to assign to a service (edit this if adding a new canary service)
  var services = ['fence', 'fenceshib', 'sheepdog', 'indexd', 'peregrine'];
  // weights for services - if given a default weight, use it; else use the default weight from this file
  var canary_weights = JSON.parse(req.variables['canary_percent_json']);
  if (typeof canary_weights['default'] === 'undefined') {
    canary_weights['default'] = DEFAULT_WEIGHT
  } else {
    canary_weights['default'] = parseInt(canary_weights['default'])
  }
  // the string to be hashed
  var hash_str = ['app', req.variables['realip'], req.variables['http_user_agent'], req.variables['date_gmt']].join();
  var hash_res = -1;

  // for each service:
  //   if it's weight == 0, ignore the cookie and set release to production
  //   else if it's in the cookie, use that release
  //   else select one by hashing and comparing to weight
  var updated_releases = {};
  for (var i=0; i < services.length; i++) {
    var service = services[i];
    var parsed_release = release_cookie.match(service+'\.(production|canary)');
    if ((!devOverride) && getWeight(service, canary_weights) === 0) {
      updated_releases[service] = 'production';
    } else if (!parsed_release) {
      // if we haven't yet generated a hash value, do that now
      if (hash_res < 0) {
        hash_res = simpleHash(hash_str);
      }
      updated_releases[service] = selectRelease(hash_res, getWeight(service, canary_weights));
    } else {
      // append the matched values from the cookie
      updated_releases[service] = parsed_release[1];
    }
  }

  return releasesObjToString(updated_releases);
}

/**
 * Controls the value of Access-Control-Allow-Credentials by environment variable
 * ORIGINS_ALLOW_CREDENTIALS.
 *
 * ORIGINS_ALLOW_CREDENTIALS is supposed to be a list of origins in JSON string. Only
 * requests with origins in this list are allowed to send credentials like cookies to
 * this website. See also: https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS#Requests_with_credentials
 *
 * In most cases, credentials shouldn't be sent cross-site to mitigate CSRF attack risks.
 * This is useful when Gen3 is deployed as an SSO and centralized service in a cross-site
 * manner. The NDEF for example, serves two sub-commons at sub1.example.com and
 * sub2.example.com with a centralized commons at example.com running Fence, Indexd and
 * Arborist. When logged in at example.com, requests sent to both sub1 and sub2 are
 * allowed to carry the same authentication cookie, therefore extra login is not needed
 * for sub1 or sub2.
 *
 * @param req - nginx request object
 * @returns {string} value used in Access-Control-Allow-Credentials header, empty string
 *          to not include this header
 */
function isCredentialsAllowed(req) {
  if (!!req.variables['http_origin']) {
    var origins = JSON.parse(req.variables['origins_allow_credentials'] || '[]') || [];
    for (var i = 0; i < origins.length; i++) {
      // cannot use === to compare byte strings, whose "typeof" is also confusingly "string"
      if (origins[i].fromUTF8().toLowerCase().trim() ===
          req.variables['http_origin'].fromUTF8().toLowerCase().trim()) {
        return 'true';
      }
    }
  }
  return '';
}

/**
 * Test whether the given ipAddrStr is in the global blackListStr.
 * Currently does not support CIDR format - just list of IP's
 * 
 * @param {string} ipAddrStr 
 * @param {string} blackListStr comma separated black list - defaults to globalBlackListStr (see below)
 * @return {boolean} true if ipAddrStr is in the black list
 */
function isOnBlackList(ipAddrStr, blackListStr) {
  return blackListStr.includes(ipAddrStr);
}

/**
 * Call via nginx.conf js_set after setting the blackListStr and
 * ipAddrStr variables via set:
 * 
 *    set blackListStr="whatever"
 *    set ipAddrStr="whatever"
 *    js_set blackListCheck checkBlackList
 * 
 * Note: kube-setup-revproxy generates gen3-blacklist.conf - which
 *   gets sucked into the nginx.conf config
 * 
 * @param {Request} req 
 * @param {Response} res 
 * @return "ok" or "block" - fail to "ok" in ambiguous situation
 */
function checkBlackList(req,res) {
  var ipAddrStr = req.variables["ip_addr_str"];
  var blackListStr = req.variables["black_list_str"];

  if (ipAddrStr && blackListStr && isOnBlackList(ipAddrStr, blackListStr)) {
    return "block";
  }
  return "ok"; // + "-" + ipAddrStr + "-" + blackListStr;
}


/**
 * Handle the js_content callout from /workspace-authorize.
 * Basically - redirect to a subdomain /wts/authorize endpoint
 * based on the state=SUBDOMAIN-... query parameter with
 * some guards to stop attacks.
 * 
 * @param {*} req 
 * @param {*} res 
 */
function gen3_workspace_authorize_handler(req) {
  var subdomain = '';
  var query = req.variables["args"] || "";
  var matchGroups = null;

  if (matchGroups = query.match(/(^state=|&state=)(\w+)-/)) {
    subdomain = matchGroups[2];
    var location = "https://" + subdomain + "." + req.variables["host"] +
      "/wts/oauth2/authorize?" + query;
    req.return(302, location);
  } else {
    req.headersOut["Content-Type"] = "application/json"
    req.return(400, '{ "status": "redirect failed validation" }');
  }
}

export default {userid, isCredentialsAllowed, checkBlackList, getServiceReleases};
