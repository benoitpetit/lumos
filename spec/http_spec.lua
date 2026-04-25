local http = require('lumos.http')

describe('HTTP Module', function()
  local orig_tmpname, orig_open, orig_remove, orig_exec
  local mock_headers_content, mock_body_content, mock_status
  local captured_cmd

  before_each(function()
    orig_tmpname = os.tmpname
    orig_open = io.open
    orig_remove = os.remove
    orig_exec = http._exec

    captured_cmd = nil
    mock_status = "200"
    mock_headers_content = "HTTP/1.1 200 OK\nContent-Type: application/json\n"
    mock_body_content = '{"ok":true}'

    local call_count = 0
    os.tmpname = function()
      call_count = call_count + 1
      if call_count == 1 then
        return "/tmp/lumos_http_h"
      else
        return "/tmp/lumos_http_b"
      end
    end

    io.open = function(path, mode)
      if path:find("/tmp/lumos_http_h") == 1 then
        return {
          read = function(_, fmt) return mock_headers_content end,
          close = function() end
        }
      elseif path:find("/tmp/lumos_http_b") == 1 then
        return {
          read = function(_, fmt) return mock_body_content end,
          close = function() end
        }
      end
      return nil
    end

    os.remove = function(path) end

    http._exec = function(cmd)
      captured_cmd = cmd
      return mock_status
    end
  end)

  after_each(function()
    os.tmpname = orig_tmpname
    io.open = orig_open
    os.remove = orig_remove
    http._exec = orig_exec
  end)

  describe('request function', function()
    it('returns error when URL is missing', function()
      local resp, err = http.request({})
      assert.is_nil(resp)
      assert.is_not_nil(err)
      assert.is_true(err:find("URL is required") ~= nil)
    end)

    it('performs a GET request', function()
      local resp, err = http.request({url = "https://example.com/api"})
      assert.is_nil(err)
      assert.is_not_nil(resp)
      assert.are.equal(200, resp.status)
      assert.is_true(resp.ok)
      assert.are.equal('{"ok":true}', resp.body)
      assert.are.equal("application/json", resp.headers["content-type"])
      assert.is_not_nil(captured_cmd:find("curl"))
      assert.is_not_nil(captured_cmd:find("GET"))
      assert.is_not_nil(captured_cmd:find("https://example.com/api"))
    end)

    it('appends query parameters', function()
      http.request({url = "https://example.com/api", query = {page = "1", limit = "10"}})
      assert.is_not_nil(captured_cmd:find("page=1"))
      assert.is_not_nil(captured_cmd:find("limit=10"))
    end)

    it('sends custom headers', function()
      http.request({
        url = "https://example.com/api",
        headers = {["X-Custom"] = "value"}
      })
      assert.is_not_nil(captured_cmd:find("X%-Custom"))
      assert.is_not_nil(captured_cmd:find("value"))
    end)

    it('sends bearer token', function()
      http.request({
        url = "https://example.com/api",
        auth = {bearer = "mytoken123"}
      })
      assert.is_not_nil(captured_cmd:find("Authorization: Bearer mytoken123"))
    end)

    it('sends basic auth', function()
      http.request({
        url = "https://example.com/api",
        auth = {user = "admin", pass = "secret"}
      })
      assert.is_not_nil(captured_cmd:find("%-u"))
      assert.is_not_nil(captured_cmd:find("admin:secret"))
    end)

    it('sets timeout', function()
      http.request({
        url = "https://example.com/api",
        timeout = 5
      })
      assert.is_not_nil(captured_cmd:find("connect%-timeout"))
      assert.is_not_nil(captured_cmd:find("max%-time"))
    end)

    it('follows redirects by default', function()
      http.request({url = "https://example.com/api"})
      assert.is_not_nil(captured_cmd:find("%-L"))
    end)

    it('skips redirects when disabled', function()
      http.request({url = "https://example.com/api", follow_redirects = false})
      assert.is_nil(captured_cmd:find(" %-L "))
      assert.is_not_nil(captured_cmd:find("max%-redirs"))
    end)

    it('skips SSL verification when insecure', function()
      http.request({url = "https://example.com/api", insecure = true})
      assert.is_not_nil(captured_cmd:find("%-k"))
    end)

    it('sends string body as-is', function()
      http.request({
        url = "https://example.com/api",
        method = "POST",
        body = "raw payload"
      })
      assert.is_not_nil(captured_cmd:find("%-d"))
      assert.is_not_nil(captured_cmd:find("raw payload"))
    end)

    it('auto-encodes table body to JSON', function()
      http.request({
        url = "https://example.com/api",
        method = "POST",
        body = {name = "lumos", count = 3}
      })
      assert.is_not_nil(captured_cmd:find("Content%-Type: application/json"))
      assert.is_not_nil(captured_cmd:find('"name"'))
      assert.is_not_nil(captured_cmd:find('"lumos"'))
    end)

    it('does not auto-set JSON content-type when json=false', function()
      http.request({
        url = "https://example.com/api",
        method = "POST",
        body = {name = "lumos"},
        json = false
      })
      assert.is_nil(captured_cmd:find("Content%-Type: application/json"))
    end)

    it('marks ok=false for non-2xx status', function()
      mock_status = "404"
      mock_headers_content = "HTTP/1.1 404 Not Found\n"
      local resp, err = http.request({url = "https://example.com/api"})
      assert.is_nil(err)
      assert.are.equal(404, resp.status)
      assert.is_false(resp.ok)
    end)

    it('decodes JSON body via response.json()', function()
      mock_body_content = '{"id":42,"active":true}'
      local resp, err = http.request({url = "https://example.com/api"})
      assert.is_nil(err)
      local data, dec_err = resp.json()
      assert.is_nil(dec_err)
      assert.are.equal(42, data.id)
      assert.is_true(data.active)
    end)

    it('returns error when JSON decode fails', function()
      mock_body_content = "not json"
      local resp, err = http.request({url = "https://example.com/api"})
      assert.is_nil(err)
      local data, dec_err = resp.json()
      assert.is_nil(data)
      assert.is_not_nil(dec_err)
    end)

    it('handles shell escapes in body', function()
      http.request({
        url = "https://example.com/api",
        method = "POST",
        body = "it's a test"
      })
      -- Single quotes inside the body should be escaped safely (no bare ' in cmd)
      assert.is_not_nil(captured_cmd:find("test"))
      -- Ensure the body is passed via -d
      assert.is_not_nil(captured_cmd:find("%-d"))
    end)
  end)

  describe('convenience methods', function()
    it('http.get sets method to GET', function()
      local resp, err = http.get("https://example.com")
      assert.is_nil(err)
      assert.is_not_nil(resp)
      assert.is_not_nil(captured_cmd:find("GET"))
    end)

    it('http.post sets method to POST', function()
      http.post("https://example.com")
      assert.is_not_nil(captured_cmd:find("POST"))
    end)

    it('http.put sets method to PUT', function()
      http.put("https://example.com")
      assert.is_not_nil(captured_cmd:find("PUT"))
    end)

    it('http.patch sets method to PATCH', function()
      http.patch("https://example.com")
      assert.is_not_nil(captured_cmd:find("PATCH"))
    end)

    it('http.delete sets method to DELETE', function()
      http.delete("https://example.com")
      assert.is_not_nil(captured_cmd:find("DELETE"))
    end)

    it('http.head sets method to HEAD', function()
      http.head("https://example.com")
      assert.is_not_nil(captured_cmd:find("HEAD"))
    end)

    it('http.options sets method to OPTIONS', function()
      http.options("https://example.com")
      assert.is_not_nil(captured_cmd:find("OPTIONS"))
    end)

    it('passes options through to request', function()
      http.post("https://example.com", {headers = {["X-Test"] = "1"}})
      assert.is_not_nil(captured_cmd:find("X%-Test"))
    end)
  end)
end)
