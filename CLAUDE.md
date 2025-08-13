# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Philosophy

**Single-file design**: This project prioritizes being completely self-contained in one executable Ruby file (`mcp_esa.rb`) using bundler/inline for dependency management. Avoid creating additional files unless absolutely necessary.

## Project Overview

This is an MCP (Model Context Protocol) server for integrating with the esa.io API. The entire server is implemented in a single Ruby file that provides tools to interact with esa.io teams, posts, comments, and members through Claude Desktop or other MCP clients.

## Architecture

### Single-file Structure

- **mcp_esa.rb**: Complete MCP server implementation with embedded dependencies via bundler/inline
  - EsaClient class for API communication
  - MCP tool definitions (both class-based and define_tool patterns)
  - Server setup and transport initialization
  - Comprehensive error handling and documentation

### Self-contained Dependencies

Uses bundler/inline to embed all dependencies within the single file:
- `mcp`: Official MCP Ruby SDK for server implementation
- `net-http`: Standard Ruby HTTP client  
- `json`: JSON parsing and generation

### API Client Design

The EsaClient class provides a clean abstraction over the esa.io REST API:
- GET, POST, PATCH methods with automatic Bearer token authentication
- Error handling for common HTTP status codes (401, 404, 429, etc.)
- URL path construction that properly handles the `/v1` API version prefix

## Available Tools

### Post Operations
- `get_posts_tool`: List posts with filtering, sorting, and pagination
- `get_post_tool`: Get detailed post information by number
- `create_post_tool`: Create new posts with optional WIP status
- `update_post_tool`: Update existing posts

### Team Operations
- `get_teams`: List teams user belongs to with role filtering
- `get_team`: Get detailed team information
- `get_members`: List team members with sorting options

### Comment Operations
- `get_comments`: List comments for a specific post
- `create_comment`: Add new comments to posts

## Configuration

### Environment Variables
Required environment variables:
- `ESA_ACCESS_TOKEN`: esa.io API access token
- `ESA_TEAM_NAME`: Default team name for operations

### MCP Configuration
Configure the single-file server in `.mcp.json` using one of these methods:

#### Method 1: Shell environment variables
Set environment variables using direnv (`.envrc` file) or shell profile (`.bashrc`, `.zshrc`, etc.):

Using direnv:
```bash
# Create .envrc file
export ESA_ACCESS_TOKEN="your_token_here"
export ESA_TEAM_NAME="your_team_name"
```
Then run `direnv allow` to activate.

Or using shell profile:
```bash
# Add to .bashrc, .zshrc, etc.
export ESA_ACCESS_TOKEN="your_token_here"
export ESA_TEAM_NAME="your_team_name"
```

Then use the basic configuration:
```json
{
  "mcpServers": {
    "esa": {
      "command": "ruby",
      "args": ["/absolute/path/to/mcp_esa.rb"]
    }
  }
}
```

#### Method 2: Direct environment variable specification
```json
{
  "mcpServers": {
    "esa": {
      "command": "ruby",
      "args": ["/absolute/path/to/mcp_esa.rb"],
      "env": {
        "ESA_ACCESS_TOKEN": "your_token_here",
        "ESA_TEAM_NAME": "your_team_name"
      }
    }
  }
}
```

## Development Commands

### Testing the Server
Test MCP server functionality:
```bash
# Test tools list
echo '{"jsonrpc":"2.0","id":0,"method":"tools/list"}' | ./mcp_esa.rb

# Test post listing
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"get_posts_tool","arguments":{}}}' | ./mcp_esa.rb
```

### Environment Setup
```bash
# Allow direnv to load environment variables
direnv allow

# Verify environment variables
env | grep ESA
```

## Key Implementation Details

### Single-file Benefits
- **Portability**: The entire server can be copied and run anywhere Ruby is available
- **Simplicity**: No complex build process or dependency management
- **Self-documenting**: All usage examples and configuration are embedded in the file header

### URI Construction
The EsaClient handles URL path construction carefully to avoid issues with URI.join:
- Removes leading slashes from paths before joining with base URL
- Ensures proper `/v1` API version inclusion in all requests

### Error Handling
Comprehensive error handling with specific messages for:
- Authentication errors (401)
- Resource not found (404) 
- Rate limiting (429) with retry information
- Generic API errors with response body details

### MCP Tool Patterns
The single file implements both MCP tool patterns for flexibility:
- Class inheritance: Tools inherit from `MCP::Tool` with class-level `call` methods
- Method definition: Using `server.define_tool` for simpler tool definitions

## Maintenance Philosophy

When modifying this project:
- Keep everything in the single `mcp_esa.rb` file
- Add new tools directly within the existing file structure
- Update the embedded documentation in the file header comments
- Preserve the bundler/inline dependency management approach