/**
 * Tests for the nginx javascript helper
 * Run with:
 *     gen3 testsuite --filter revproxy
 */

// Hacky way of getting our functions into node.js scripts
// source: https://stackoverflow.com/questions/5797852/in-node-js-how-do-i-include-functions-from-my-other-files
const fs = require('fs');
eval(fs.readFileSync('helpers.js')+'');

const crypto = require('crypto');

const log = (str) => console.log('LOGGED: ' + str);

describe("Nginx helper function", function() {

  it("userid returns correct user and uuid from access_token", function() {
    const uuid = '1234567890abcdefghijklmnop';
    const user = 'jimmyjoe@joetown.gov';
    // access token with uuid and user above
    const access_token = 'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwYWJjZGVmZ2hpamtsbW5vcCIsImNvbnRleHQiOnsidXNlciI6eyJuYW1lIjoiamltbXlqb2VAam9ldG93bi5nb3YifX0sImlhdCI6MTU0MTAwMTg4M30.Mo7zS3PV-Ji3hhCgtLLQsBGvRIIXnziqfo9e2_COwTkc4X_AwcU3fvcP7vQx0d11uglAFzg3V8y0QX1JMFR5YT9kEegkyu5NOnvNcQ9gbp3Jg_9oJAdrWxW-RKgKvzDzvFBLhwlkHpMyQHM4fOnMg9U4N6IgZdbZ5Ez754uKGH8';
    const nginxRequest = {
      variables: {
        access_token: access_token
      }
    };
    // expect the user and uuid to be in the returned string
    const parsedUser = userid(nginxRequest);
    expect(parsedUser).toMatch(uuid);
    expect(parsedUser).toMatch(user);
  });

  it("MathAbs returns positive given negative", function() {
    expect(MathAbs(-72)).toBe(72);
  });

  it("MathAbs returns positive given positive", function() {
    expect(MathAbs(72)).toBe(72);
  });

  it("simpleHash returns an integer between 0 and 100", function() {
    let counts = [];
    for (var i = 0; i < 100; i++) counts[i] = 0;
    for (let i=0; i < 500; i++) {
      const randString = crypto.randomBytes(36).toString('hex') + crypto.randomBytes(36).toString('hex');
      const hashVal = simpleHash(randString, 100);
      expect(hashVal).toBeGreaterThan(-1);
      expect(hashVal).toBeLessThan(100);
      counts[hashVal]++
    }
    // print the distribution
    console.log('\nHash histogram (make sure it looks uniform):');
    counts.forEach(val => console.log('#'.repeat(val)));
  });

  it("getWeight returns weight of defined service", function() {
    const weights = {
      fence: 32,
      default: 99
    };
    const w = getWeight('fence', weights);
    expect(w).toBe(weights['fence'])
  });

  it("getWeight returns default if service weight undefined", function() {
    const weights = {
      fence: 32,
      default: 99
    };
    const w = getWeight('sheepdog', weights);
    expect(w).toBe(weights['default'])
  });

  it("selectRelease returns canary if hash val below weight", function() {
    const hashVal = 0;
    const serviceWeight = 100;
    expect(selectRelease(hashVal, serviceWeight)).toEqual('canary');
  });

  it("selectRelease returns production if hash val above weight", function() {
    const hashVal = 100;
    const serviceWeight = 0;
    expect(selectRelease(hashVal, serviceWeight)).toEqual('production');
  });

  it("selectRelease uses default weight if service weight is undefined", function() {
    const hashVal = 100;
    var serviceWeight;
    const defaultWeight = 0;
    expect(selectRelease(hashVal, serviceWeight, defaultWeight)).toEqual('production');
  });

  // mock user request information submitted with request
  const propertiesForHash = {
    realip: '128.135.98.222',
    http_user_agent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/69.0.3497.100 Safari/537.36',
    date_gmt: '24/Oct/2018:17:19:36 +0000'
  };

  it("getServiceReleases returns original release versions if in cookie", function() {
    const cookie = 'fence.production';
    let nginxRequest = {
      variables: {
        cookie_service_releases: cookie,
        canary_percent_json: '{ "fence": 100 }',
        ...propertiesForHash,
      },
      log: log,
    };

    const serviceReleases = getServiceReleases(nginxRequest);
    expect(serviceReleases).toMatch('fence.production');
  });

  it("getServiceReleases returns dev override release versions if in cookie", function() {
    const cookie = 'fence.production';
    const devCookie = 'fence.canary';
    let nginxRequest = {
      variables: {
        cookie_service_releases: cookie,
        cookie_dev_canaries: devCookie,
        canary_percent_json: '{ "fence": 0 }',
        ...propertiesForHash,
      },
      log: log,
    };

    const serviceReleases = getServiceReleases(nginxRequest);
    expect(serviceReleases).toMatch('fence.canary');
  });

  it("getServiceReleases returns correct release version when no cookie val is set (test 1)", function() {
    // don't define the service release cookie, forcing it to hash and select a release
    let nginxRequest = {
      variables: {
        canary_percent_json: '{ "fence": 100 }',
        ...propertiesForHash,
      },
      log: log,
    };

    const serviceReleases = getServiceReleases(nginxRequest);
    expect(serviceReleases).toMatch('fence.canary');
  });

  it("getServiceReleases returns correct release version when no cookie val is set (test 2)", function() {
    // don't define the service release cookie, forcing it to hash and select a release
    let nginxRequest = {
      variables: {
        canary_percent_json: '{ "fence": 0, "sheepdog": 100 }',
        ...propertiesForHash,
      },
      log: log,
    };

    const serviceReleases = getServiceReleases(nginxRequest);
    expect(serviceReleases).toMatch('fence.production');
    expect(serviceReleases).toMatch('sheepdog.canary');
  });

  it("getServiceReleases uses manifest default weight if service weight not present", function() {
    // don't define the service release cookie, forcing it to hash and select a release
    let nginxRequest = {
      variables: {
        canary_percent_json: '{ "default": 100 }',
        ...propertiesForHash,
      },
      log: log,
    };

    const serviceReleases = getServiceReleases(nginxRequest);
    expect(serviceReleases).toMatch('fence.canary');
  });

  it("getServiceReleases uses script's default weight if NO weights are provided", function() {
    // don't define the service release cookie, forcing it to hash and select a release
    let nginxRequest = {
      variables: {
        canary_percent_json: '{}', // provide no weights - script should use it's default
        ...propertiesForHash,
      },
      log: log,
    };

    // default weight in script is 0 (ie it should always be assigned production)
    const serviceReleases = getServiceReleases(nginxRequest);
    expect(serviceReleases).toMatch('fence.production');
  });

  it("getServiceReleases sets service to production when weight is 0", function() {
    // set fence to canary, and weight to 0 - should ignore the cookie and set to production
    const cookie = 'fence.canary';
    let nginxRequest = {
      variables: {
        cookie_service_releases: cookie,
        canary_percent_json: '{ "fence": 0 }', // provide no weights - script should use it's default
        ...propertiesForHash,
      },
      log: log,
    };

    const serviceReleases = getServiceReleases(nginxRequest);
    expect(serviceReleases).toMatch('fence.production');
  });

  it("can check an item against a black list", function() {
    const blackList = "quick,brown,fox";
    blackList.split(',').forEach(
      (testStr) => {
        expect(isOnBlackList(testStr, blackList)).toBe(true, `${testStr} is on black list ${blackList}`);
      }
    );
    const testStr="frickjack";
    expect(isOnBlackList(testStr, blackList)).toBe(false, `${testStr} is not on black list ${blackList}`);
  });

  function ReqMock(query) {
    return Object.assign(this, {
      uri: "/workspace-authorize/",
      variables: {
        host: "workspace.planx-pla.net",
        args: query
      },
      headersOut: {},
      returnArgs: [],
      "return": function(code, content) {
        this.returnArgs.push({code, content});
      }
    });
  }

  it("can handle a valid wts authorize redirect", function() {
    const goodReq = new ReqMock("code=whateer&state=frick123-bla&bla");
    gen3_workspace_authorize_handler(goodReq);
    expect(goodReq.returnArgs.length).toBe(1);
    expect(goodReq.returnArgs[0].code).toBe(302);
    expect(goodReq.returnArgs[0].content).toBe("https://frick123.workspace.planx-pla.net/wts/oauth2/authorize?code=whateer&state=frick123-bla&bla");
  });

  it("can handle invalid wts authorize redirects", function() {
    [
      "code=whateer&state=frick123.bad-bla&bla",
      "code=whateer&state=bla&bla"
    ].forEach(
      (badUri) => {
        const badReq = new ReqMock(badUri);
        gen3_workspace_authorize_handler(badReq);
        expect(badReq.returnArgs.length).toBe(1);
        expect(badReq.returnArgs[0].code).toBe(400);
      }
    );
  });

});
