/**
 * Tests for the nginx javascript helper
 */

// Hacky way of getting our functions into node.js scripts
// source: https://stackoverflow.com/questions/5797852/in-node-js-how-do-i-include-functions-from-my-other-files
const fs = require('fs');
eval(fs.readFileSync('helpers.js')+'');

const crypto = require('crypto');
const jwt  = require('jsonwebtoken');

// THIS IS A FAKE PRIVATE KEY - it's not used for anything
const fakePrivateKey = `-----BEGIN RSA PRIVATE KEY-----
    MIICWgIBAAKBgHt5O3e0d6auiEIl0z7iBVKB3pDWxqCZ0B5fXx16mXuezYTD3A9K
  MM/hjAqWhgbW+N7ZNvx59mFl3EGA/+hpHmw2sn59tIE2JaZvNDwVutldnySXix6J
  pYRw9WNDdLwW3Oq/uW+dgfvA4Rt0OXd5Pj5UMxog4SanWbKWG/Sw44OvAgMBAAEC
  gYBMtcjoWcpsV8p3riBL1QgRdnXb7lOAu469D+t72Qs57jMo5LX3GdSxkiL7AQFL
  hosfiDvNJ8iWQj5Qw+A5d/VZyd8+pOoRwWDlr/xBPjAklKiL0ENRLGhpe7w7YiKm
  25Elh53ybUlK5SJ+CAdbCbT5Z6aSguLIpacFnTdz4n9b4QJBAOQot8Eylb3XcF1r
  ILh0azSBiyN5xUR9sfzk21smOjYVW+M6mQ4ymSlbiTLuUxEo6ulCLcS/UI2d9Wlu
  isHhJLUCQQCKilOMl7U5qnED3ZI1AGVT9r1wDJyMMZ5d/1V+CTAtb6cM9mMz0RtT
  wmn5boisFp00EHkDfv6DdxwWo7L02UlTAkAJhKFVz/RrPQeU/hkZWNH4GMdjLXtL
  Riscr7du8ANRqkZxDkrASuAU15q7ozGX76sNHBOot4p2vfY09cWYHPpZAkBuo32J
  v/Y4sUdEIQUMUt6ZKWmsPEYhJ9cjljA+UTQqdQphrbsXvJ0oTRC45G89j2nIFIew
  JRE5CDxkUCMwqv6FAkAAm3zqGq7HXJvxGOTm3tx2ahahXFT4NoaltYC+JX3gbneA
  impyGFchHwISN9LcR0b8EUws/erweiaw73Idld8B
-----END RSA PRIVATE KEY----- `;
const tokenSignOptions = {algorithm:  "RS256"};


describe("Nginx helper function", function() {

  it("userid returns correct user and uuid from access_token", function() {
    // construct a token with a uuid and user
    const uuid = '1234567890abcdefghijklmnop';
    const user = 'jimmyjoe@joetown.gov';
    const payload = {
      sub: uuid,
      context: {
        user: {
          name: user,
        },
      },
    };
    const access_token = jwt.sign(payload, fakePrivateKey, tokenSignOptions);
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

  it("selectRelease returns canary if hash val below weight", function() {
    const hashVal = 0;
    const serviceWeight = 100;
    const defaultWeight = 0;
    expect(selectRelease(hashVal, serviceWeight, defaultWeight)).toEqual('canary');
  });

  it("selectRelease returns production if hash val above weight", function() {
    const hashVal = 100;
    const serviceWeight = 0;
    const defaultWeight = 0;
    expect(selectRelease(hashVal, serviceWeight, defaultWeight)).toEqual('production');
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
        ...propertiesForHash
      }
    };

    const serviceReleases = getServiceReleases(nginxRequest);
    expect(serviceReleases).toMatch('fence.production');
  });

  it("getServiceReleases returns correct release version when no cookie val is set (test 1)", function() {
    // don't define the service release cookie, forcing it to hash and select a release
    let nginxRequest = {
      variables: {
        canary_percent_json: '{ "fence": 100 }',
        ...propertiesForHash
      }
    };

    const serviceReleases = getServiceReleases(nginxRequest);
    expect(serviceReleases).toMatch('fence.canary');
  });

  it("getServiceReleases returns correct release version when no cookie val is set (test 2)", function() {
    // don't define the service release cookie, forcing it to hash and select a release
    let nginxRequest = {
      variables: {
        canary_percent_json: '{ "fence": 0, "sheepdog": 100 }',
        ...propertiesForHash
      }
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
        ...propertiesForHash
      }
    };

    const serviceReleases = getServiceReleases(nginxRequest);
    expect(serviceReleases).toMatch('fence.canary');
  });

  it("getServiceReleases uses script's default weight if NO weights are provided", function() {
    // don't define the service release cookie, forcing it to hash and select a release
    let nginxRequest = {
      variables: {
        canary_percent_json: '{}', // provide no weights - script should use it's default
        ...propertiesForHash
      }
    };

    // default weight in script is 0 (ie it should always be assigned production)
    const serviceReleases = getServiceReleases(nginxRequest);
    expect(serviceReleases).toMatch('fence.production');
  });

});
