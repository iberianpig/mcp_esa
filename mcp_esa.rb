#!/usr/bin/env ruby

# example
#
# .envrc
# ```bash
# # Please set ESA_ACCESS_TOKEN and ESA_TEAM_NAME environment variables
# export ESA_ACCESS_TOKEN=xxxxxxxxxxxx
# export ESA_TEAM_NAME=your-team-name
# ```
#
# check if the environment variables are set
# ```bash
# $ echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"get_posts_tool","arguments":{}}}' | ./mcp_esa.rb
# ```
#
# .mcp.json
# ```json
# {
#   "mcpServers": {
#     "esa": {
#       "command": "ruby",
#       "args": ["/path/to/mcp_esa.rb"]
#     }
#   }
# }
# ```

require 'bundler/inline'

gemfile(true, quiet: true) do
  source "https://rubygems.org"
  gem "mcp"
  gem "net-http"
  gem "json"
  gem "base64"
end

require 'mcp'
require 'mcp/server/transports/stdio_transport'
require 'net/http'
require 'uri'
require 'json'
require 'base64'

# The EsaClient class manages HTTP requests to the Esa API
class EsaClient
  def initialize(access_token, team_name)
    @access_token = access_token
    @team_name = team_name
    @base_url = "https://api.esa.io/v1"
  end

  # Sends an HTTP GET request to the specified endpoint
  def get(path, params = {})
    uri = build_uri(path, params)
    request = Net::HTTP::Get.new(uri)
    set_headers(request)
    execute_request(uri, request)
  end

  # Sends an HTTP POST request to the specified endpoint
  def post(path, body = {})
    uri = build_uri(path)
    request = Net::HTTP::Post.new(uri)
    set_headers(request)
    request.body = body.to_json
    execute_request(uri, request)
  end

  # Sends an HTTP PATCH request to the specified endpoint
  def patch(path, body = {})
    uri = build_uri(path)
    request = Net::HTTP::Patch.new(uri)
    set_headers(request)
    request.body = body.to_json
    execute_request(uri, request)
  end

  # Sends an HTTP POST request with form-data to the specified URL (for S3 upload)
  def post_form_data(url, form_data)
    uri = URI(url)
    request = Net::HTTP::Post.new(uri)

    # Build multipart form data
    boundary = "----formdata-mcp-esa-#{Time.now.to_i}"
    request['Content-Type'] = "multipart/form-data; boundary=#{boundary}"

    body_parts = []
    form_data.each do |key, value|
      if key == :file
        # File upload part
        file_content = value[:content]
        filename = value[:filename]
        content_type = value[:content_type]

        body_parts << "--#{boundary}\r\n"
        body_parts << "Content-Disposition: form-data; name=\"file\"; filename=\"#{filename}\"\r\n"
        body_parts << "Content-Type: #{content_type}\r\n\r\n"
        body_parts << file_content
        body_parts << "\r\n"
      else
        # Regular form field
        body_parts << "--#{boundary}\r\n"
        body_parts << "Content-Disposition: form-data; name=\"#{key}\"\r\n\r\n"
        body_parts << value.to_s
        body_parts << "\r\n"
      end
    end
    body_parts << "--#{boundary}--\r\n"

    request.body = body_parts.join

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    response = http.request(request)
    handle_s3_response(response)
  end

  # Sends a POST request with form-encoded data (for attachment policies)
  def post_form_encoded(path, params = {})
    uri = build_uri(path)
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{@access_token}"
    request['Content-Type'] = 'application/x-www-form-urlencoded'
    request.body = URI.encode_www_form(params)
    execute_request(uri, request)
  end

  private

  # Constructs a URI for the given path and parameters
  def build_uri(path, params = {})
    path = path[1..-1] if path.start_with?("/")
    uri = URI.join(@base_url + "/", path)
    uri.query = URI.encode_www_form(params) unless params.empty?
    uri
  end

  # Sets headers for the request
  def set_headers(request)
    request['Authorization'] = "Bearer #{@access_token}"
    request['Content-Type'] = 'application/json'
  end

  # Executes the HTTP request and handles the response
  def execute_request(uri, request)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    response = http.request(request)
    handle_response(response)
  end

  # Processes the HTTP response, raising errors or returning parsed JSON
  def handle_response(response)
    case response.code.to_i
    when 200, 201, 204
      response.body.empty? ? {} : JSON.parse(response.body)
    when 401
      raise "Authentication error: Invalid access token"
    when 404
      raise "Resource not found: #{response.uri} - #{response.body}"
    when 429
      retry_after = response['Retry-After'] || 60
      raise "Rate limit exceeded. Retry after #{retry_after} seconds"
    else
      begin
        error_body = JSON.parse(response.body)
        error_message = error_body['message'] || "Unknown error"
      rescue JSON::ParserError
        error_message = "HTTP error #{response.code}"
      end
      raise "Error: #{error_message}"
    end
  end

  # Handles S3 upload response (expects 204 No Content for success)
  def handle_s3_response(response)
    case response.code.to_i
    when 204
      { success: true }
    else
      raise "S3 upload failed with status #{response.code}: #{response.body}"
    end
  end

end

# Server setup
access_token = ENV['ESA_ACCESS_TOKEN']
team_name = ENV['ESA_TEAM_NAME']

unless access_token && team_name
  STDERR.puts "Please set ESA_ACCESS_TOKEN and ESA_TEAM_NAME environment variables"
  exit 1
end

esa_client = EsaClient.new(access_token, team_name)

# Define tools using class inheritance
class GetPostsTool < MCP::Tool
  description "Get a list of posts from the specified team"
  input_schema(
    type: "object",
    properties: {
      q: {
        type: "string",
        description: "Search query to filter posts (optional)"
      },
      sort: {
        type: "string",
        enum: ["updated", "created", "number", "stars", "watches", "comments", "best_match"],
        description: "Sort method (default: updated)"
      },
      order: {
        type: "string",
        enum: ["desc", "asc"],
        description: "Sort order (default: desc)"
      },
      page: {
        type: "integer",
        description: "Page number (default: 1)"
      },
      per_page: {
        type: "integer",
        description: "Items per page (default: 20, max: 100)"
      }
    }
  )

  class << self
    def call(**args)
      begin
        params = args.compact
        esa_client = EsaClient.new(ENV['ESA_ACCESS_TOKEN'], ENV['ESA_TEAM_NAME'])
        result = esa_client.get("/teams/#{ENV['ESA_TEAM_NAME']}/posts", params)

        posts_text = result['posts'].map do |post|
          "- ##{post['number']}: #{post['full_name']} (#{post['wip'] ? 'WIP' : 'Published'})"
        end.join("\n")

        MCP::Tool::Response.new([
          {
            type: "text",
            text: "Posts list:\n\n#{posts_text}\n\nPage info: #{result['page']}/#{(result['total_count'].to_f / result['per_page']).ceil} (total: #{result['total_count']})"
          }
        ])
      rescue => e
        MCP::Tool::Response.new([
          {
            type: "text",
            text: "Error: #{e.message}\n#{e.backtrace.join("\n")}"
          }
        ])
      end
    end
  end
end

class GetPostTool < MCP::Tool
  description "Get details of a specified post"
  input_schema(
    type: "object",
    properties: {
      post_number: {
        type: "integer",
        description: "Post number"
      },
      include: {
        type: "string",
        description: "Additional information (comments, stargazers, etc.)"
      }
    },
    required: ["post_number"]
  )

  class << self
    def call(post_number:, include: nil)
      params = {}
      params[:include] = include if include

      team_name = ENV['ESA_TEAM_NAME']
      esa_client = EsaClient.new(ENV['ESA_ACCESS_TOKEN'], team_name)
      result = esa_client.get("/teams/#{team_name}/posts/#{post_number}", params)

      post_detail = <<~TEXT
        Post details:

        Number: ##{result['number']}
        Title: #{result['full_name']}
        Status: #{result['wip'] ? 'WIP' : 'Published'}
        Category: #{result['category'] || 'None'}
        Tags: #{result['tags']&.join(', ') || 'None'}
        Created by: #{result['created_by']['name']} (@#{result['created_by']['screen_name']})
        Created at: #{result['created_at']}
        Updated at: #{result['updated_at']}
        Revision: #{result['revision_number']}
        Comments: #{result['comments_count']}
        Stars: #{result['stargazers_count']}
        Watches: #{result['watchers_count']}
        URL: #{result['url']}

        Content:
        #{result['body_md']}
      TEXT

      MCP::Tool::Response.new([
        { type: "text", text: post_detail }
      ])
    end
  end
end

class CreatePostTool < MCP::Tool
  description "Create a new post"
  input_schema(
    type: "object",
    properties: {
      name: {
        type: "string",
        description: "Post title"
      },
      body_md: {
        type: "string",
        description: "Post content in Markdown format"
      },
      category: {
        type: "string",
        description: "Category (optional)"
      },
      tags: {
        type: "array",
        items: { type: "string" },
        description: "List of tags (optional)"
      },
      wip: {
        type: "boolean",
        description: "WIP flag (default: true)"
      },
      message: {
        type: "string",
        description: "Change message (optional)"
      }
    },
    required: ["name"]
  )

  class << self
    def call(name:, body_md: nil, category: nil, tags: nil, wip: true, message: nil)
      post_params = { name: name }
      post_params[:body_md] = body_md if body_md
      post_params[:category] = category if category
      post_params[:tags] = tags if tags
      post_params[:wip] = wip
      post_params[:message] = message if message

      team_name = ENV['ESA_TEAM_NAME']
      esa_client = EsaClient.new(ENV['ESA_ACCESS_TOKEN'], team_name)
      result = esa_client.post("/teams/#{team_name}/posts", { post: post_params })

      MCP::Tool::Response.new([
        { type: "text", text: "Post created successfully: ##{result['number']} - #{result['full_name']}" }
      ])
    end
  end
end

class UpdatePostTool < MCP::Tool
  description "Update an existing post"
  input_schema(
    type: "object",
    properties: {
      post_number: {
        type: "integer",
        description: "Number of the post to update"
      },
      name: {
        type: "string",
        description: "Post title (optional)"
      },
      body_md: {
        type: "string",
        description: "Post content in Markdown format (optional)"
      },
      category: {
        type: "string",
        description: "Category (optional)"
      },
      tags: {
        type: "array",
        items: { type: "string" },
        description: "List of tags (optional)"
      },
      wip: {
        type: "boolean",
        description: "WIP flag (optional)"
      },
      message: {
        type: "string",
        description: "Change message (optional)"
      }
    },
    required: ["post_number"]
  )

  class << self
    def call(post_number:, name: nil, body_md: nil, category: nil, tags: nil, wip: nil, message: nil)
      post_params = {}
      post_params[:name] = name if name
      post_params[:body_md] = body_md if body_md
      post_params[:category] = category if category
      post_params[:tags] = tags if tags
      post_params[:wip] = wip unless wip.nil?
      post_params[:message] = message if message

      team_name = ENV['ESA_TEAM_NAME']
      esa_client = EsaClient.new(ENV['ESA_ACCESS_TOKEN'], team_name)
      result = esa_client.patch("/teams/#{team_name}/posts/#{post_number}", { post: post_params })

      MCP::Tool::Response.new([
        { type: "text", text: "Post updated successfully: ##{result['number']} - #{result['full_name']}" }
      ])
    end
  end
end

class UploadAttachmentTool < MCP::Tool
  description "Upload a file attachment to esa.io (beta feature)"
  input_schema(
    type: "object",
    properties: {
      file_path: {
        type: "string",
        description: "Path to the file to upload"
      },
      team_name: {
        type: "string",
        description: "Team name (uses ESA_TEAM_NAME env var if omitted)"
      }
    },
    required: ["file_path"]
  )

  class << self
    def call(file_path:, team_name: nil)
      begin
        team_name ||= ENV['ESA_TEAM_NAME']
        esa_client = EsaClient.new(ENV['ESA_ACCESS_TOKEN'], team_name)

        # Validate file existence
        unless File.exist?(file_path)
          raise "File not found: #{file_path}"
        end

        # Read file and get metadata
        file_content = File.read(file_path)
        filename = File.basename(file_path)
        file_size = file_content.bytesize

        # Determine content type based on file extension
        content_type = case File.extname(filename).downcase
        when '.png' then 'image/png'
        when '.jpg', '.jpeg' then 'image/jpeg'
        when '.gif' then 'image/gif'
        when '.webp' then 'image/webp'
        when '.svg' then 'image/svg+xml'
        when '.bmp' then 'image/bmp'
        when '.pdf' then 'application/pdf'
        when '.txt' then 'text/plain'
        when '.md' then 'text/markdown'
        else 'application/octet-stream'
        end

        # Step 1: Get upload policy from esa.io
        policy_params = {
          type: content_type,
          name: filename,
          size: file_size
        }

        policy_result = esa_client.post_form_encoded("/teams/#{team_name}/attachments/policies", policy_params)

        # Step 2: Upload file to S3 using the policy
        attachment = policy_result['attachment']
        form_data = policy_result['form']

        # Prepare form data for S3 upload
        upload_data = {}
        form_data.each { |key, value| upload_data[key.to_sym] = value }
        upload_data[:file] = {
          content: file_content,
          filename: filename,
          content_type: content_type
        }

        # Upload to S3
        s3_result = esa_client.post_form_data(attachment['endpoint'], upload_data)

        if s3_result[:success]
          response_text = <<~TEXT
            File uploaded successfully!

            Filename: #{filename}
            Size: #{file_size} bytes
            Content-Type: #{content_type}
            URL: #{attachment['url']}

            You can now use this URL in your esa posts:
            ![#{filename}](#{attachment['url']})
          TEXT

          MCP::Tool::Response.new([
            { type: "text", text: response_text }
          ])
        else
          raise "S3 upload failed"
        end

      rescue => e
        MCP::Tool::Response.new([
          {
            type: "text",
            text: "Error uploading file: #{e.message}\n#{e.backtrace.join("\n")}"
          }
        ])
      end
    end
  end
end

# Define resources
recent_posts_resource = MCP::Resource.new(
  uri: "esa://teams/#{team_name}/posts/recent",
  name: "recent_posts",
  description: "Recently updated posts from the esa team",
  mime_type: "application/json"
)

# Set up the server
server = MCP::Server.new(
  name: "esa-mcp-server",
  version: "1.0.0",
  tools: [
    GetPostsTool,
    GetPostTool,
    CreatePostTool,
    UpdatePostTool,
    UploadAttachmentTool
  ],
  resources: [recent_posts_resource]
)

# Add additional tools using define_tool method
server.define_tool(
  name: "get_teams",
  description: "Get a list of teams you belong to",
  input_schema: {
    type: "object",
    properties: {
      role: {
        type: "string",
        enum: ["member", "owner"],
        description: "Filter by role (optional)"
      }
    }
  }
) do |role: nil|
  params = {}
  params[:role] = role if role

  esa_client = EsaClient.new(ENV['ESA_ACCESS_TOKEN'], ENV['ESA_TEAM_NAME'])
  result = esa_client.get("/teams", params)

  teams_text = result['teams'].map do |team|
    "- #{team['name']}: #{team['description']}\n  URL: #{team['url']}\n  Privacy: #{team['privacy']}"
  end.join("\n\n")

  MCP::Tool::Response.new([
    { type: "text", text: "Teams list:\n\n#{teams_text}" }
  ])
end

server.define_tool(
  name: "get_team",
  description: "Get details of a specified team",
  input_schema: {
    type: "object",
    properties: {
      team_name: {
        type: "string",
        description: "Team name (uses ESA_TEAM_NAME env var if omitted)"
      }
    }
  }
) do |team_name: nil|
  team_name ||= ENV['ESA_TEAM_NAME']
  esa_client = EsaClient.new(ENV['ESA_ACCESS_TOKEN'], team_name)
  result = esa_client.get("/teams/#{team_name}")

  team_detail = <<~TEXT
    Team details:

    Name: #{result['name']}
    Description: #{result['description']}
    URL: #{result['url']}
    Privacy: #{result['privacy']}
    Icon: #{result['icon']}
  TEXT

  MCP::Tool::Response.new([
    { type: "text", text: team_detail }
  ])
end

server.define_tool(
  name: "get_members",
  description: "Get a list of team members",
  input_schema: {
    type: "object",
    properties: {
      team_name: {
        type: "string",
        description: "Team name (uses ESA_TEAM_NAME env var if omitted)"
      },
      sort: {
        type: "string",
        enum: ["posts_count", "joined", "last_accessed"],
        description: "Sort method (default: posts_count)"
      },
      order: {
        type: "string",
        enum: ["desc", "asc"],
        description: "Sort order (default: desc)"
      }
    }
  }
) do |team_name: nil, sort: nil, order: nil|
  team_name ||= ENV['ESA_TEAM_NAME']
  params = {}
  params[:sort] = sort if sort
  params[:order] = order if order

  esa_client = EsaClient.new(ENV['ESA_ACCESS_TOKEN'], team_name)
  result = esa_client.get("/teams/#{team_name}/members", params)

  members_text = result['members'].map do |member|
    myself_mark = member['myself'] ? " (me)" : ""
    "- #{member['name']} (@#{member['screen_name']})#{myself_mark}\n" +
    "  Role: #{member['role']}\n" +
    "  Posts: #{member['posts_count']}\n" +
    "  Joined: #{member['joined_at']}\n" +
    "  Last access: #{member['last_accessed_at']}"
  end.join("\n\n")

  MCP::Tool::Response.new([
    { type: "text", text: "Members list:\n\n#{members_text}" }
  ])
end

server.define_tool(
  name: "get_comments",
  description: "Get a list of comments for a post",
  input_schema: {
    type: "object",
    properties: {
      post_number: {
        type: "integer",
        description: "Post number"
      },
      team_name: {
        type: "string",
        description: "Team name (uses ESA_TEAM_NAME env var if omitted)"
      }
    },
    required: ["post_number"]
  }
) do |post_number:, team_name: nil|
  team_name ||= ENV['ESA_TEAM_NAME']

  esa_client = EsaClient.new(ENV['ESA_ACCESS_TOKEN'], team_name)
  result = esa_client.get("/teams/#{team_name}/posts/#{post_number}/comments")

  if result['comments'].empty?
    comments_text = "No comments."
  else
    comments_text = result['comments'].map do |comment|
      "ID: #{comment['id']}\n" +
      "Author: #{comment['created_by']['name']} (@#{comment['created_by']['screen_name']})\n" +
      "Posted: #{comment['created_at']}\n" +
      "Content:\n#{comment['body_md']}\n" +
      "URL: #{comment['url']}"
    end.join("\n#{'-' * 50}\n")
  end

  MCP::Tool::Response.new([
    { type: "text", text: "Comments list:\n\n#{comments_text}" }
  ])
end

server.define_tool(
  name: "create_comment",
  description: "Create a new comment on a post",
  input_schema: {
    type: "object",
    properties: {
      post_number: {
        type: "integer",
        description: "Post number to comment on"
      },
      body_md: {
        type: "string",
        description: "Comment content in Markdown format"
      },
      team_name: {
        type: "string",
        description: "Team name (uses ESA_TEAM_NAME env var if omitted)"
      }
    },
    required: ["post_number", "body_md"]
  }
) do |post_number:, body_md:, team_name: nil|
  team_name ||= ENV['ESA_TEAM_NAME']

  comment_params = { body_md: body_md }
  esa_client = EsaClient.new(ENV['ESA_ACCESS_TOKEN'], team_name)
  result = esa_client.post("/teams/#{team_name}/posts/#{post_number}/comments", { comment: comment_params })

  MCP::Tool::Response.new([
    { type: "text", text: "Comment created successfully: ID #{result['id']}" }
  ])
end

# Category management tools
server.define_tool(
  name: "get_categories",
  description: "Get a list of categories under the specified path",
  input_schema: {
    type: "object",
    properties: {
      select: {
        type: "string",
        description: "Category path to retrieve (e.g., 'dev' or 'dev/api'). Required to specify which categories to get."
      },
      include: {
        type: "string",
        enum: ["posts", "parent_categories"],
        description: "Additional information to include (optional)"
      },
      page: {
        type: "integer",
        description: "Page number (default: 1)"
      },
      per_page: {
        type: "integer",
        description: "Items per page (default: 20, max: 100)"
      },
      team_name: {
        type: "string",
        description: "Team name (uses ESA_TEAM_NAME env var if omitted)"
      }
    },
    required: ["select"]
  }
) do |select:, include: nil, page: nil, per_page: nil, team_name: nil|
  team_name ||= ENV['ESA_TEAM_NAME']
  params = { select: select }
  params[:include] = include if include
  params[:page] = page if page
  params[:per_page] = per_page if per_page

  esa_client = EsaClient.new(ENV['ESA_ACCESS_TOKEN'], team_name)
  result = esa_client.get("/teams/#{team_name}/categories", params)

  categories_text = result['categories'].map do |category|
    "- #{category['full_name']} (#{category['count']} posts)"
  end.join("\n")

  MCP::Tool::Response.new([
    { type: "text", text: "Categories under '#{select}':\n\n#{categories_text}" }
  ])
end

server.define_tool(
  name: "get_top_categories",
  description: "Get a list of top-level categories (categories at the root level)",
  input_schema: {
    type: "object",
    properties: {
      team_name: {
        type: "string",
        description: "Team name (uses ESA_TEAM_NAME env var if omitted)"
      }
    }
  }
) do |team_name: nil|
  team_name ||= ENV['ESA_TEAM_NAME']

  esa_client = EsaClient.new(ENV['ESA_ACCESS_TOKEN'], team_name)
  result = esa_client.get("/teams/#{team_name}/categories/top")

  categories_text = result['categories'].map do |category|
    "- #{category['full_name']} (#{category['count']} posts)"
  end.join("\n")

  MCP::Tool::Response.new([
    { type: "text", text: "Top-level categories:\n\n#{categories_text}" }
  ])
end

server.define_tool(
  name: "get_all_category_paths",
  description: "Get all category paths in the team with post counts. Useful for understanding category structure and planning organization.",
  input_schema: {
    type: "object",
    properties: {
      prefix: {
        type: "string",
        description: "Filter paths starting with this prefix (e.g., 'dev' finds 'dev', 'dev/api', 'dev/docs')"
      },
      match: {
        type: "string",
        description: "Filter paths containing this string (e.g., 'api' finds 'dev/api', 'backend/api')"
      },
      team_name: {
        type: "string",
        description: "Team name (uses ESA_TEAM_NAME env var if omitted)"
      }
    }
  }
) do |prefix: nil, match: nil, team_name: nil|
  team_name ||= ENV['ESA_TEAM_NAME']

  esa_client = EsaClient.new(ENV['ESA_ACCESS_TOKEN'], team_name)
  result = esa_client.get("/teams/#{team_name}/categories/paths")

  # Extract categories and filter out null paths
  categories = result['categories'] || []
  paths_with_counts = categories.map { |cat| { path: cat['path'], posts: cat['posts'] } }.reject { |cat| cat[:path].nil? }

  # Apply filters if specified
  filtered_paths = paths_with_counts
  filtered_paths = filtered_paths.select { |cat| cat[:path].start_with?(prefix) } if prefix
  filtered_paths = filtered_paths.select { |cat| cat[:path].include?(match) } if match

  if filtered_paths.empty?
    filter_info = [prefix ? "prefix: #{prefix}" : nil, match ? "match: #{match}" : nil].compact.join(", ")
    message = filter_info.empty? ? "No categories found." : "No categories found matching filters (#{filter_info})."

    MCP::Tool::Response.new([
      { type: "text", text: message }
    ])
  else
    paths_text = filtered_paths.map { |cat| "- #{cat[:path]} (#{cat[:posts]} posts)" }.join("\n")
    filter_info = [prefix ? "prefix: #{prefix}" : nil, match ? "match: #{match}" : nil].compact.join(", ")
    header = filter_info.empty? ? "All category paths:" : "Category paths (filtered by #{filter_info}):"

    MCP::Tool::Response.new([
      { type: "text", text: "#{header}\n\n#{paths_text}\n\nTotal: #{filtered_paths.length} categories" }
    ])
  end
end

# Resource handler for reading recent posts
server.resources_read_handler do |params|
  uri = params[:uri]

  # Extract team name from URI: esa://teams/{team_name}/posts/recent
  if uri =~ %r{^esa://teams/([^/]+)/posts/recent$}
    team_name = $1
    esa_client = EsaClient.new(ENV['ESA_ACCESS_TOKEN'], team_name)

    # Get recent posts (sorted by updated, descending)
    result = esa_client.get("/teams/#{team_name}/posts", { sort: "updated", order: "desc", per_page: 20 })

    posts_data = result['posts'].map do |post|
      {
        number: post['number'],
        name: post['name'],
        full_name: post['full_name'],
        wip: post['wip'],
        body_md: post['body_md'],
        url: post['url'],
        updated_at: post['updated_at'],
        category: post['category'],
        tags: post['tags']
      }
    end

    [{
      uri: uri,
      mimeType: "application/json",
      text: JSON.pretty_generate(posts_data)
    }]
  else
    raise "Unknown resource URI: #{uri}"
  end
end

# Define prompt for summarizing posts
server.define_prompt(
  name: "summarize_post",
  description: "Summarize a post from esa",
  arguments: [
    MCP::Prompt::Argument.new(
      name: "team_name",
      description: "Team name",
      required: true
    ),
    MCP::Prompt::Argument.new(
      name: "post_number",
      description: "Post number to summarize",
      required: true
    )
  ]
) do |args|
  team_name = args[:team_name]
  post_number = args[:post_number]

  esa_client = EsaClient.new(ENV['ESA_ACCESS_TOKEN'], team_name)
  result = esa_client.get("/teams/#{team_name}/posts/#{post_number}")

  # Create a prompt message that asks to summarize the post
  prompt_text = <<~PROMPT
    Please summarize the following esa post:

    Title: #{result['full_name']}
    Category: #{result['category'] || 'None'}
    Tags: #{result['tags']&.join(', ') || 'None'}
    Status: #{result['wip'] ? 'WIP (Work In Progress)' : 'Published'}
    Updated: #{result['updated_at']}

    Content:
    #{result['body_md']}

    Please provide a concise summary that includes:
    1. Main topic and purpose
    2. Key points and findings
    3. Important notes or conclusions
  PROMPT

  MCP::Prompt::Result.new(
    messages: [
      MCP::Prompt::Message.new(
        role: "user",
        content: MCP::Content::Text.new(prompt_text)
      )
    ]
  )
end

# Create and start the transport
transport = MCP::Server::Transports::StdioTransport.new(server)
transport.open
