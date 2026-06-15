#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"
require "tempfile"
require "time"

list_path, out_path, proxy_port, api_port = ARGV
proxy_port ||= "19191"
api_port ||= "19192"
abort "usage: audit-mihomo-routing.rb list.txt out.tsv [proxy_port] [api_port]" unless list_path && out_path

def capture_json(*cmd)
  stdout, stderr, status = Open3.capture3(*cmd)
  raise "command failed: #{cmd.join(' ')}: #{stderr}" unless status.success?

  JSON.parse(stdout)
end

def rule_counts(api_port)
  data = capture_json(
    "/usr/bin/curl",
    "-sS",
    "-H", "Authorization: Bearer set-your-secret",
    "http://127.0.0.1:#{api_port}/rules"
  )
  data.fetch("rules").map do |rule|
    key = [rule["index"], rule["type"], rule["payload"], rule["proxy"]].join("\t")
    [key, [rule.fetch("extra", {}).fetch("hitCount", 0).to_i, rule]]
  end.to_h
end

def run_with_timeout(timeout_seconds, *cmd)
  stdout_file = Tempfile.new("routing-audit-stdout")
  stderr_file = Tempfile.new("routing-audit-stderr")
  pid = spawn(*cmd, out: stdout_file.path, err: stderr_file.path)
  deadline = Time.now + timeout_seconds
  status = nil

  loop do
    finished_pid, status = Process.waitpid2(pid, Process::WNOHANG)
    break if finished_pid || Time.now >= deadline

    sleep 0.05
  end

  if status.nil?
    begin
      Process.kill("TERM", pid)
      sleep 0.2
      Process.kill("KILL", pid)
    rescue Errno::ESRCH
      nil
    end
    begin
      Process.wait(pid)
    rescue Errno::ECHILD
      nil
    end
  end

  [File.read(stdout_file.path), File.read(stderr_file.path), status ? status.exitstatus : "TIMEOUT"]
ensure
  stdout_file&.close!
  stderr_file&.close!
end

domains = File.readlines(list_path, chomp: true).map(&:strip).reject(&:empty?)

File.open(out_path, "w") do |out|
  out.sync = true
  domains.each do |domain|
    before = rule_counts(api_port)
    started = Time.now.utc.iso8601
    stdout, stderr, status_code = run_with_timeout(
      12,
      "/usr/bin/curl",
      "-k",
      "-I",
      "--proxy", "http://127.0.0.1:#{proxy_port}",
      "--connect-timeout", "3",
      "--max-time", "8",
      "-A", "Mozilla/5.0 routing-audit",
      "-o", "/dev/null",
      "-sS",
      "-w", "%{http_code}",
      "https://#{domain}/"
    )
    after = rule_counts(api_port)
    deltas = after.map do |key, (count, rule)|
      previous = before[key]&.[](0) || 0
      delta = count - previous
      delta.positive? ? [delta, rule] : nil
    end.compact
    best = deltas.max_by { |delta, rule| [delta, -rule["index"].to_i] }

    if best
      delta, rule = best
      out.puts [
        domain, started, status_code, stdout.strip, rule["index"], rule["type"],
        rule["payload"], rule["proxy"], delta, stderr.strip.gsub(/\s+/, " ")
      ].join("\t")
    else
      out.puts [
        domain, started, status_code, stdout.strip, "", "", "", "NO_RULE_HIT",
        0, stderr.strip.gsub(/\s+/, " ")
      ].join("\t")
    end
  end
end
