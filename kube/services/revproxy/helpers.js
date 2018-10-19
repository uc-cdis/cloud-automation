/**
 * This is a helper script used in the reverse proxy
 * Note that this is not technically javascript, but nginscript (or njs)
 * See here for info: http://nginx.org/en/docs/njs/
 */

/** global supporting atob polyfill below */
var chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';

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
 * Checks cookie for service release versions and assigns
 *   release versions for services not in the cookie based
 *   on hash value and the percent weight of the canary.
 * Returns a string of service assignments. E.g:
 *   "fence.canary&sheepdog.production&"
 *
 * @param req - nginx request object
 */
function getServiceReleases(req) {

  var release_cookie = req.variables['cookie_service_releases'];
  var services = ['fence', 'sheepdog'];
  var canary_weights = {
    fence: GEN3_CANARY_PERCENT_FENCE|-10-|,
    sheepdog: GEN3_CANARY_PERCENT_SHEEPDOG|-10-|
  }
  var generated_release = "";

  // if not given a release for a service, select one by hasing user info
  var updated_release = "";
  for (var i=0; i < services.length; i++) {
    var name = services[i];
    var release_val = release_cookie.match(name+'\.(production|canary)')
    if (!release_val) {
      // if we haven't yet generated a release selection, hash request info
      //   and select release based on weighting
      if (!generated_release) {
        // hash user info to select the release
        var hash_str = ['app', req.variables['realip'], req.variables['http_user_agent'], req.variables['date_gmt']].join();
        var hash_res = simpleHash(hash_str, 100);
        generated_release = 'production';
        if (hash_res < canary_weights[name]) {
          generated_release = 'canary';
        }
      }
      updated_release = updated_release + name + '.' + generated_release + '&';
    } else {
      updated_release = updated_release + release_val[0] + "&";
    }
  }

  return updated_release
}