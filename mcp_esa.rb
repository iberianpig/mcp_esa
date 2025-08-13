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

gemfile(true) do
  source "https://rubygems.org"
  gem "mcp"
  gem "net-http"
  gem "json"
end

require 'mcp'
require 'mcp/server/transports/stdio_transport'
require 'net/http'
require 'uri'
require 'json'

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

# Set up the server
server = MCP::Server.new(
  name: "esa-mcp-server",
  version: "1.0.0",
  tools: [
    GetPostsTool,
    GetPostTool,
    CreatePostTool,
    UpdatePostTool
  ]
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

# Create and start the transport
transport = MCP::Server::Transports::StdioTransport.new(server)
transport.open
