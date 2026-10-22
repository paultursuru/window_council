# frozen_string_literal: true

require 'fileutils'
require_relative '../config/settings'

# Files in DATA_DIR, written by the plugin and by the form server.
module Storage
  module_function

  # Never leaves a half-written file; the temporary name is per process
  def write_atomically(path, content)
    tmp = "#{path}.#{Process.pid}.tmp"
    File.write(tmp, content)
    File.rename(tmp, path)
  end

  # One writer at a time: a plugin run and a form submission can overlap
  def locked
    FileUtils.mkdir_p(DATA_DIR)
    File.open(LOCK_FILE, File::RDWR | File::CREAT) do |f|
      f.flock(File::LOCK_EX)
      yield
    end
  end
end
