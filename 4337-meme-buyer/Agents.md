# Agents

## Development Framework Rules

### Smart Contract Development

- **[Foundry](.cursor/rules/foundry.mdc)**: Foundry development workflow, testing, and deployment
- **[Hardhat](.cursor/rules/hardhat.mdc)**: Hardhat development workflow, testing, and deployment

### Chainlink Integration

- **[Chainlink](.cursor/rules/chainlink.mdc)**: Chainlink Data Feeds, CCIP, and Data Streams addresses and configuration for Monad testnet

### Frontend Development

- **[Next.js](.cursor/rules/next-js.mdc)**: Next.js App Router, React Server Components, TypeScript best practices
- **[Next.js with Supabase](.cursor/rules/nextjs_with_supabase.mdc)**: Next.js integration with Supabase for database and authentication
- **[React](.cursor/rules/react.mdc)**: React development guidelines and best practices

### Backend Development

- **[NestJS](.cursor/rules/nest-js.mdc)**: NestJS framework guidelines, TypeScript patterns, and clean architecture principles

### Project Configuration

- **[Requirements](.cursor/rules/requirements.mdc)**: Project overview, tech stack, and task priorities

## Monad MCP configuration
```json
{
  "mcpServers": {
    "MonadMcp": {
      "url": "https://monad-mcp-tau.vercel.app/sse"
    }
  }
}
```