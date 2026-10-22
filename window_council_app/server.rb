# frozen_string_literal: true

require 'fileutils'
require 'io/wait'
require 'socket'
require 'timeout'
require 'uri'
require_relative 'controller'

# Serves the page and its readings form on 127.0.0.1. Started from the xbar menu, it stops
# after SERVER_IDLE minutes without a request; the open page reloads every 5 min.
class Server
  include ApplicationHelper

  URL = "http://#{SERVER_HOST}:#{SERVER_PORT}/"
  # Other hosts or origins are refused: another site could post to 127.0.0.1 from the browser
  HOSTS = ["#{SERVER_HOST}:#{SERVER_PORT}", "localhost:#{SERVER_PORT}"].freeze
  PING = 'window_council'
  STATUS = { 200 => 'OK', 303 => 'See Other', 403 => 'Forbidden', 404 => 'Not Found',
             500 => 'Internal Server Error' }.freeze

  def initialize(plugin_path: Dir[File.expand_path('../window_council.*.rb', __dir__)].min)
    @plugin_path = plugin_path || File.expand_path('../window_council.10m.rb', __dir__)
  end

  # Opens the page, starting the server unless it already runs. Detached first, so xbar,
  # which launched it, gets its hand back.
  def start
    Process.daemon(true)
    return open_page if running?

    FileUtils.mkdir_p(DATA_DIR)
    $stderr.reopen(LOG_FILE, 'w')
    server = TCPServer.new(SERVER_HOST, SERVER_PORT)
    open_page
    serve(server)
  rescue Errno::EADDRINUSE
    system('osascript', '-e', %(display notification "Port #{SERVER_PORT} déjà utilisé" with title "Window Council"))
  end

  # [status, headers, body] for one request
  def handle(method, target, headers, body)
    return text(403, 'Hôte refusé') unless HOSTS.include?(headers['host'])

    case "#{method} #{target.to_s.split('?').first}"
    when 'GET /' then [200, { 'Content-Type' => 'text/html; charset=utf-8' }, page]
    when 'GET /report.json' then [200, { 'Content-Type' => 'application/json' }, File.read(JSON_FILE)]
    when 'GET /ping' then text(200, PING)
    when 'POST /readings' then add_reading(headers['origin'], body)
    else text(404, 'Introuvable')
    end
  rescue StandardError => e
    warn "#{iso(Time.now)} #{e.class}: #{e.message}"
    text(500, "Erreur : #{e.message}")
  end

  private

  # Saves the reading, rebuilds the report and refreshes xbar, then back to the page.
  # The outdoor dew point at that time is kept with it, to measure airings later.
  def add_reading(origin, body)
    return text(403, 'Origine refusée') unless origin.nil? || HOSTS.include?(origin.sub(%r{\Ahttps?://}, ''))

    params = URI.decode_www_form(body.to_s).to_h
    reading = Readings.parse(params, Time.now)
    dew = History.dew_point_at(History.read(JSON_FILE), time_at(reading['at']))
    Readings.add(dew ? reading.merge('outdoor_dew_point' => dew) : reading)
    Controller.new(plugin_path: @plugin_path).refresh
    refresh_xbar
    redirect('ok' => time_label(reading['at'])) # with the date when not today: a later time means yesterday
  rescue Readings::Invalid => e
    redirect(params.merge('erreur' => e.message)) # the page puts the values back in the form
  end

  def page
    Controller.new(plugin_path: @plugin_path).refresh unless File.exist?(HTML_FILE)
    File.read(HTML_FILE, encoding: 'UTF-8')
  end

  def redirect(params)
    [303, { 'Location' => "/?#{URI.encode_www_form(params)}" }, '']
  end

  def text(status, message)
    [status, { 'Content-Type' => 'text/plain; charset=utf-8' }, message]
  end

  def refresh_xbar
    system('open', '-g', "xbar://app.xbarapp.com/refreshPlugin?path=#{File.basename(@plugin_path)}")
  end

  def open_page
    system('open', URL)
  end

  def running?
    Socket.tcp(SERVER_HOST, SERVER_PORT, connect_timeout: 1) do |s|
      s.write("GET /ping HTTP/1.0\r\nHost: #{HOSTS[0]}\r\n\r\n")
      Timeout.timeout(2) { s.read.to_s.end_with?(PING) }
    end
  rescue SystemCallError, Timeout::Error
    false
  end

  def serve(server)
    while server.wait_readable(SERVER_IDLE * 60)
      client = server.accept
      begin
        respond(client, *Timeout.timeout(5) { read_request(client) })
      rescue StandardError => e
        warn "#{iso(Time.now)} #{e.class}: #{e.message}"
      ensure
        client.close
      end
    end
  end

  def read_request(client)
    method, target = client.gets.to_s.split
    headers = {}
    while (line = client.gets) && !line.strip.empty?
      name, value = line.split(':', 2)
      headers[name.strip.downcase] = value.to_s.strip
    end
    length = headers['content-length'].to_i
    [method, target, headers, length.positive? ? client.read([length, 65_536].min) : '']
  end

  def respond(client, method, target, headers, body)
    status, head, content = handle(method, target, headers, body)
    head = head.merge('Content-Length' => content.bytesize, 'Cache-Control' => 'no-store', 'Connection' => 'close')
    client.write("HTTP/1.1 #{status} #{STATUS[status]}\r\n", *head.map { |k, v| "#{k}: #{v}\r\n" }, "\r\n", content)
  end
end

Server.new.start if $PROGRAM_NAME == __FILE__
