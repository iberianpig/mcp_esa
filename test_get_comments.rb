#!/usr/bin/env ruby

require 'json'
require 'open3'
require 'minitest/autorun'

class GetCommentsToolTest < Minitest::Test
  MCP_ESA_PATH = File.expand_path('mcp_esa.rb', __dir__)

  def send_jsonrpc(request)
    env = {
      'ESA_ACCESS_TOKEN' => 'dummy_token',
      'ESA_TEAM_NAME' => 'dummy_team'
    }
    input = request.to_json
    stdout, stderr, status = Open3.capture3(env, 'ruby', MCP_ESA_PATH, stdin_data: input)
    # MCP server may output multiple lines; find the JSON response
    stdout.lines.map(&:strip).reject(&:empty?).map { |line|
      JSON.parse(line) rescue nil
    }.compact
  end

  def get_tool_schema(tool_name)
    responses = send_jsonrpc({ jsonrpc: "2.0", id: 0, method: "tools/list" })
    tools_response = responses.find { |r| r['id'] == 0 }
    assert tools_response, "Expected tools/list response"
    tools = tools_response.dig('result', 'tools') || []
    tools.find { |t| t['name'] == tool_name }
  end

  def test_get_comments_has_page_parameter
    tool = get_tool_schema('get_comments')
    assert tool, "get_comments tool should exist"

    properties = tool.dig('inputSchema', 'properties')
    assert properties.key?('page'), "get_comments should have a 'page' parameter"
    assert_equal 'integer', properties['page']['type']
  end

  def test_get_comments_has_per_page_parameter
    tool = get_tool_schema('get_comments')
    assert tool, "get_comments tool should exist"

    properties = tool.dig('inputSchema', 'properties')
    assert properties.key?('per_page'), "get_comments should have a 'per_page' parameter"
    assert_equal 'integer', properties['per_page']['type']
  end
end
