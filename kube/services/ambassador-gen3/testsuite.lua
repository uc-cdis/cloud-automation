--
-- testsuite.lua
-- run with: gen3 testsuite --filter lua
--

-- lib .....................

function assert(rule, description)
  if not rule then
    print("Failed test: " .. description)
    return false
  end
  return true
end

function run_test(test, description)
  print("running test: " .. description)
  if test() then
    print("test passed: " .. description)
    return true
  else
    print("test failed: " .. description)
    return false
  end
end

function test_string_split()
  local t = string_split("abc=123;def=456;", ";")
  if not assert(t[1] == "abc=123" and t[2] == "def=456", "string_split gave expected table: " .. nil_check(t[1]) .. ", " .. nil_check(t[2])) then
    return false
  end
  return true
end

function test_lookup_cookie()
  local t = string_split("abc=123;def=456;", ";")
  local v = lookup_cookie(t, "abc")
  local result = assert(v == "123", "cookie abc is as expected 123 ?= " .. nil_check(v))
  v = lookup_cookie(t, "def")
  result = assert(v == "456", "cookie def is as expected 456 ?= " .. nil_check(v)) and result
  return result
end

function mockRequest()
  return {
    header_table = {},
    response = nil,
    headers = function(self)
       return self
    end,
    get = function(self, key)
       return self.header_table[key]
    end,
    replace = function(self, key, value)
      self.header_table[key] = value
    end,
    respond = function(self, headers, data)
      self.response = data
    end
  }
end

function test_handle_auth()
  local mock = mockRequest()
  local cookie_table = {}
  handle_auth(mock, cookie_table)
  local result = assert(nil == mock.header_table["Authorization"], "no authorization header if no authorization cookie")
  
  mock = mockRequest()
  mock.header_table["Cookie"] = "abc=123;access_token=bogus;csrf=bla"
  cookie_table = string_split(mock.header_table["Cookie"], ";")
  handle_auth(mock, cookie_table)
  result = assert("bearer bogus" == mock.header_table["Authorization"], "authorization header gets cookie value if no existing header: " .. nil_check(mock.header_table["Authorization"])) and result
  
  mock = mockRequest()
  mock.header_table["Cookie"] = "abc=123;access_token=bogus;csrf=bla"
  mock.header_table["Authorization"] = "whatever"
  cookie_table = string_split(mock.header_table["Cookie"], ";")
  handle_auth(mock, cookie_table)
  result = assert("whatever" == mock.header_table["Authorization"], "existing authorization header is not modified") and result

  return result
end

function test_handle_csrf()
  local mock = mockRequest()
  local cookie_table = {}
  mock.header_table[":method"] = "GET"
  handle_csrf(mock, cookie_table)
  local result = assert(nil == mock.response, 'CSRF check on GET request does not require CSRF')
  
  mock = mockRequest()
  mock.header_table[":method"] = "POST"
  handle_csrf(mock, cookie_table)
  result = assert(nil ~= mock.response, 'CSRF check on POST request requires CSRF') and result
  
  mock = mockRequest()
  mock.header_table[":method"] = "POST"
  mock.header_table["x-csrf-token"] = "Bla"
  cookie_table[1] = "csrftoken=FRICK;"
  handle_csrf(mock, cookie_table)
  result = assert(nil ~= mock.response, 'CSRF check on POST request CSRF header must match cookie') and result
  
  mock = mockRequest()
  mock.header_table[":method"] = "POST"
  mock.header_table["x-csrf-token"] = "FRICK"
  cookie_table = {}
  cookie_table[1] = "csrftoken=FRICK"
  handle_csrf(mock, cookie_table)
  result = assert(nil == mock.response, 'CSRF check on POST request passes when CSRF header matches cookie ' .. nil_check(mock.response)) and result

  mock = mockRequest()
  mock.header_table[":method"] = "POST"
  mock.header_table["Authorization"] = "FRICK"
  cookie_table = {}
  handle_csrf(mock, cookie_table)
  result = assert(nil == mock.response, 'CSRF check on POST request passes when Authorization header present') and result

  return result  
end

function run_all_tests()
  success = run_test(test_string_split, "test_string_split")
  success = run_test(test_lookup_cookie, "test_lookup_cookie") and success
  success = run_test(test_handle_auth, "test_handle_auth") and success
  success = run_test(test_handle_csrf, "test_handle_csrf") and success
  if success then
    print "---- ALL TESTS SUCCEEDED ----"
  end
  return success
end

-- main ....................

if run_all_tests() then
  os.exit(0)
else
  os.exit(1)
end
