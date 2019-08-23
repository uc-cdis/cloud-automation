function string_split(inputstr, sep)
  if sep == nil then
    sep = "%s"
  end
  local t={}
  for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
    -- print (str)
    table.insert(t, str)
  end
  return t
end

function lookup_cookie(cookie_table, cookie_name)
    local i, cookie_item
    for i, cookie_item in ipairs(cookie_table) do
      if string.find(cookie_item, cookie_name) ~= nil then
        return string.gsub(string.gsub(cookie_item, cookie_name .. "=", ""), "^ ", "")
      end
    end
    return nil
end

function handle_auth(request_handle, cookie_table)
  local auth_header = request_handle:headers():get("Authorization")
  if cookie_table ~= nil and auth_header == nil then
    local jwt = lookup_cookie(cookie_table, "access_token")
    if jwt ~= nil then
      local auth = "bearer " .. jwt
      request_handle:headers():replace("Authorization", auth)
    end
  end
  return true
end

function nil_check(str)
  if str == nill then
    return ""
  else
    return str
  end
end

function handle_csrf(request_handle, cookie_table)
  local auth_header = request_handle:headers():get("Authorization")
  local method = request_handle:headers():get(":method")
  if auth_header == nil and (method == "POST" or method == "DELETE" or method == "PUT") then
    -- cookie authenticated update request - verify CSRF
    local csrf_header = request_handle:headers():get("x-csrf-token")
    local csrf_cookie = lookup_cookie(cookie_table, "csrftoken")
    if csrf_header == nill or csrf_header ~= csrf_cookie then
      request_handle:respond(
        {[":status"] = "403", ["content-type"] = "application/json"},
        "{\"error\": \"failed csrf " .. nil_check(csrf_header) .. " ?= " .. nil_check(csrf_cookie) .. " check\"}"
      )
      return false
    end
  end
  return true
end

function envoy_on_request(request_handle)
  -- Wait for the entire request body and add a request header with the body size.
  local cookie_header = request_handle:headers():get("Cookie")
  local cookie_table = {}
  if cookie_header ~= nil then
    cookie_table = string_split(cookie_header, ";")
  end
  -- filters - handle CSRF first, as handle_auth modifies headers
  return handle_csrf(request_handle, cookie_table) and handle_auth(request_handle, cookie_table)
end
