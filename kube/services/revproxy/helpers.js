/**
 * This is a helper script used in the reverse proxy
 * Note that this is not technically javascript, but nginscript (or njs)
 * See here for info: http://nginx.org/en/docs/njs/
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
    user = token;
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
  return hash_res < parseInt(w) ? 'canary' : 'production';
}

function getWeight(service, weights) {
  return weights[service] ? weights[service] : weights['default'];
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
 * Checks cookie for service release versions and assigns
 *   release versions for services not in the cookie based
 *   on hash value and the percent weight of the canary.
 *   If the weight for a service is 0, it ignores the cookie
 *   and sets the release to production.
 * Returns a string of service assignments. E.g:
 *   "fence.canary&sheepdog.production&"
 *
 * @param req - nginx request object
 */
function getServiceReleases(req) {
  // client cookie containing releases
  var release_cookie = req.variables['cookie_service_releases'] || '';
  // services to assign to a service (edit this if adding a new canary service)
  var services = ['fence', 'sheepdog', 'indexd', 'peregrine'];
  // weights for services - if given a default weight, use it; else use the default weight from this file
  var canary_weights = JSON.parse(req.variables['canary_percent_json']);
  if (typeof canary_weights['default'] === 'undefined') {
    canary_weights['default'] = DEFAULT_WEIGHT
  } else {
    canary_weights['default'] = parseInt(canary_weights['default'])
  }
  // canary_weights['default'] = canary_weights['default'] ? parseInt(canary_weights['default']) : DEFAULT_WEIGHT;
  // the string to be hashed
  var hash_str = ['app', req.variables['realip'], req.variables['http_user_agent'], req.variables['date_gmt']].join();
  var hash_res = -1;

  req.log(req.variables['canary_percent_json']);

  // for each service:
  //   if it's weight == 0, ignore the cookie and set release to production
  //   else if it's in the cookie, use that release
  //   else select one by hashing and comparing to weight
  var updated_releases = {};
  for (var i=0; i < services.length; i++) {
    var service = services[i];
    var parsed_release = release_cookie.match(service+'\.(production|canary)');
    if (getWeight(service, canary_weights) === 0) {
      req.log('weight 0 for ' + service)
      updated_releases[service] = 'production+WEIGHT_ZERO';
    } else if (!parsed_release) {
      // if we haven't yet generated a hash value, do that now
      if (hash_res < 0) {
        hash_res = simpleHash(hash_str);
      }
      updated_releases[service] = selectRelease(hash_res, getWeight(service, canary_weights)) + "+SELECTED_RELEASE";
      req.log('selected release for ' + service + ': ' + updated_releases[service]);
    } else {
      // append the matched values from the cookie
      req.log('already had release for ' + service + ': ' + parsed_release[1]);
      updated_releases[service] = parsed_release[1] + "+PARSED_RELEASE";
    }
  }

  return releasesObjToString(updated_releases);
}