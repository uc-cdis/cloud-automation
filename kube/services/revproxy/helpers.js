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
 * @param size - range to hash into
 */
function simpleHash(s, size) {
  var i, hash = 0;
  for (i = 0; i < s.length; i++) {
    hash += (s[i].charCodeAt() * (i+1));
  }
  return MathAbs(hash) % size;
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
function selectRelease(hash_res, service_weight, default_weight) {
  // determine release by comparing hash val to service weight
  // if service weight is not defined use default value
  service_weight = typeof service_weight === 'undefined' ? default_weight : service_weight;
  if (hash_res < parseInt(service_weight)) {
    return 'canary';
  }
  return 'production';
}

/**
 * Checks cookie for service release versions and assigns
 *   release versions for services not in the cookie based
 *   on hash value and the percent weight of the canary.
 * Returns a string of service assignments. E.g:
 *   "fence.canary&sheepdog.production&"
 *
 * @param req - nginx request object
 */
function getServiceReleases(req) {

  var release_cookie = req.variables['cookie_service_releases'] || '';
  var services = ['fence', 'sheepdog', 'indexd', 'peregrine'];
  var canary_weights = JSON.parse(req.variables['canary_percent_json']);
  var hash_res;

  // if given a default weight, use it; else use the default weight from this file
  var default_weight = parseInt(canary_weights['default']);
  default_weight = default_weight ? default_weight : DEFAULT_WEIGHT;

  // if release for a service is not in the cookie, select one by hashing user info
  var updated_release = "";
  for (var i=0; i < services.length; i++) {
    var name = services[i];
    var release_val = release_cookie.match(name+'\.(production|canary)');
    if (!release_val) {
      // if we haven't yet generated a hash value, do that now
      if (typeof hash_res === 'undefined') {
        // hash user info to get a value between 0 and 99
        var hash_str = ['app', req.variables['realip'], req.variables['http_user_agent'], req.variables['date_gmt']].join();
        hash_res = simpleHash(hash_str, 100);
      }
      var selected_release = selectRelease(hash_res, canary_weights[name], default_weight);
      updated_release = updated_release + name + '.' + selected_release + '&';
    } else {
      // append the matched values from the cookie
      updated_release = updated_release + release_val[0] + "&";
    }
  }

  return updated_release
}