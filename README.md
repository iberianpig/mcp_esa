# MCP ESA Server

A Model Context Protocol (MCP) server for esa.io API integration. Enables Claude Desktop and other MCP clients to interact with esa.io teams, posts, comments, and members.

## Installation

### From GitHub
```bash
# Clone the repository
git clone https://github.com/iberianpig/mcp_esa.git
cd mcp_esa

# Make the script executable
chmod +x mcp_esa.rb
```

### Direct Download
```bash
# Download the single file
curl -O https://raw.githubusercontent.com/iberianpig/mcp_esa/main/mcp_esa.rb
chmod +x mcp_esa.rb
```

## Setup

### Environment Variables
```bash
export ESA_ACCESS_TOKEN="your_token_here"
export ESA_TEAM_NAME="your_team_name"
```

### MCP Configuration

#### Using Claude Code CLI (Recommended)

```bash
# Add as local configuration (default)
claude mcp add --transport stdio \
  --env ESA_ACCESS_TOKEN=$ESA_ACCESS_TOKEN \
  --env ESA_TEAM_NAME=your_team_name \
  esa -- ruby /absolute/path/to/mcp_esa.rb

# Add for project sharing (saves to .mcp.json)
claude mcp add --transport stdio --scope project \
  --env ESA_ACCESS_TOKEN=$ESA_ACCESS_TOKEN \
  --env ESA_TEAM_NAME=your_team_name \
  esa -- ruby /absolute/path/to/mcp_esa.rb
```

**Options:**
- `--transport stdio`: Run as a local process
- `--scope`: Where to save the config (`local`=personal, `project`=team shared, `user`=cross-project)
- `--env KEY=value`: Set environment variables (can specify multiple)

**Management commands:**
```bash
claude mcp list          # List all servers
claude mcp get esa       # Show server details
claude mcp remove esa    # Remove a server
```

#### Manual `.mcp.json` Configuration

```json
{
  "mcpServers": {
    "esa": {
      "command": "ruby",
      "args": ["/path/to/mcp_esa/mcp_esa.rb"]
    }
  }
}
```

## Usage

### With Claude Desktop
```
Show me the latest posts from esa.io
```
```
Create a new post titled "Meeting Notes"
```
```
Show comments for post #123
```

### Command Line Test


```bash
echo '{"jsonrpc":"2.0","id":0,"method":"tools/list"}' | ./mcp_esa.rb
```

list posts with filtering and pagination:
```bash
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"get_posts_tool","arguments":{}}}' | ./mcp_esa.rb
```

## Available Tools

**Posts**
- `get_posts_tool` - List posts with filtering and pagination
- `get_post_tool` - Get detailed post information
- `create_post_tool` - Create new posts
- `update_post_tool` - Update existing posts

**Teams**
- `get_teams` - List teams you belong to
- `get_team` - Get team details
- `get_members` - List team members

**Comments**
- `get_comments` - List comments for a post
- `create_comment` - Add new comments
