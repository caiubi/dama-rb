# Minimal Rack app that serves static files from a dist/ directory.
# Used by Capybara to auto-start a server for web integration tests.
# Serves index.html for root path requests.
class DamaWebApp
  def initialize(dist_dir:)
    @dist_dir = dist_dir
  end

  def call(env)
    path = env["PATH_INFO"]
    # Serve index.html for root path.
    path = "/index.html" if path == "/" || path.empty?

    file_path = File.join(dist_dir, path)
    return not_found unless File.file?(file_path)

    content = File.binread(file_path)
    content_type = mime_type(file_path)
    [200, { "content-type" => content_type, "content-length" => content.bytesize.to_s }, [content]]
  end

  private

  attr_reader :dist_dir

  MIME_TYPES = {
    ".html" => "text/html",
    ".js" => "application/javascript",
    ".wasm" => "application/wasm",
    ".css" => "text/css",
    ".png" => "image/png",
    ".svg" => "image/svg+xml",
    ".json" => "application/json",
  }.freeze

  def mime_type(path)
    ext = File.extname(path)
    MIME_TYPES.fetch(ext, "application/octet-stream")
  end

  def not_found
    [404, { "content-type" => "text/plain" }, ["Not found"]]
  end
end
