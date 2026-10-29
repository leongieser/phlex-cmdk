require 'socket'
ENV['FERRUM_JS_API'] ||= 'new' # evaluate() awaits returned promises (the Ferrum 0.21 behaviour)
require 'ferrum'
require_relative '../../lib/cmdk'

# Headless-Chrome harness for the JS runtime: a tiny local HTTP server (module
# scripts don't load from file://) serving the runtime and generated pages,
# and a Ferrum browser to drive them. Dev-only; used by `rake test:browser`
# and `rake bench`.
module CmdkBrowser
  ROOT = File.expand_path('../..', __dir__)

  class Server
    TYPES = { '.js' => 'text/javascript', '.css' => 'text/css', '.html' => 'text/html' }.freeze

    attr_reader :port

    def initialize
      @pages = {}
      @headers = {}
      @server = TCPServer.new('127.0.0.1', 0)
      @port = @server.addr[1]
      @thread = Thread.new { loop { handle(@server.accept) } }
    end

    # Register an HTML page at `path`; `headers` adds response headers (e.g. CSP).
    def page(path, html, headers = {})
      @pages[path] = html
      @headers[path] = headers
      "http://127.0.0.1:#{port}#{path}"
    end

    def stop
      @thread.kill
      @server.close
    end

    private

    def handle(client)
      request_line = client.gets.to_s
      while (line = client.gets) && line != "\r\n"; end
      path = request_line.split[1].to_s.sub(/\?.*/, '')
      body, type, headers = resolve(path)
      status = body ? '200 OK' : '404 Not Found'
      body ||= 'not found'
      head = ["HTTP/1.1 #{status}", "Content-Type: #{type}; charset=utf-8",
              "Content-Length: #{body.bytesize}", 'Cache-Control: no-store', 'Connection: close']
      headers.each { |k, v| head << "#{k}: #{v}" }
      client.write(head.join("\r\n") + "\r\n\r\n" + body)
    rescue StandardError
      nil
    ensure
      client&.close
    end

    def resolve(path)
      return [@pages[path], 'text/html', @headers[path] || {}] if @pages.key?(path)

      # CMDK_JS=path/to/other/cmdk.js serves another runtime (e.g. to compare releases).
      file = { '/cmdk.js' => ENV.fetch('CMDK_JS', Cmdk.javascript_path),
               '/cmdk_base.css' => Cmdk.base_stylesheet_path,
               '/cmdk_themes.css' => Cmdk.stylesheet_path }[path]
      return [nil, 'text/plain', {}] unless file && File.exist?(file)

      [File.read(file), TYPES.fetch(File.extname(file)), {}]
    end
  end

  def self.browser
    Ferrum::Browser.new(headless: true, window_size: [1200, 900], timeout: 30,
                        process_timeout: 30, browser_options: { 'no-sandbox' => nil })
  end

  # Poll until `expression` is truthy in the page (no sleeps on the Ruby side).
  def self.wait_for(page, expression, timeout: 10)
    page.evaluate(<<~JS, timeout: timeout)
      new Promise((resolve) => {
        const check = () => (#{expression}) ? resolve(true) : setTimeout(check, 5)
        check()
      })
    JS
  end

  # A full HTML document around `body`; `head` is extra head markup.
  def self.document(body, head: '', script: '<script type="module" src="/cmdk.js"></script>')
    <<~HTML
      <!doctype html>
      <html lang="en">
      <head>
      <meta charset="utf-8">
      #{head}
      #{script}
      </head>
      <body>
      #{body}
      </body>
      </html>
    HTML
  end

  # Render a Phlex block to HTML (kit methods like Cmdk::Item(...) work).
  def self.render(&block)
    Class.new(Phlex::HTML) { define_method(:view_template, &block) }.new.call
  end
end
