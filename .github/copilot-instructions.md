# Copilot Instructions for Hytale Server Project

## Shell Script Best Practices

1. **Modularization**: Ensure all shell script functionality is properly modularized
   - Break down complex scripts into reusable functions
   - Use shared library files for common operations (e.g., `auth-manager.sh` with multiple commands)
   - Each function should have a single, well-defined responsibility
   - Use command-line arguments to switch between different modes/behaviors

2. **Code Optimization**: Write concise, efficient code
   - Don't write 20 lines when one line will do
   - Combine operations where logical (e.g., pipe commands together)
   - Avoid unnecessary variable declarations
   - Use shell built-ins over external commands when possible

3. **Code Reusability**: Avoid duplication
   - Extract repeated logic into shared functions
   - Consolidate similar operations into parameterized functions

4. **Comments**: Only add comments when necessary
   - Code should be self-documenting with clear variable and function names
   - Only comment complex logic, non-obvious workarounds, or important warnings
   - Avoid stating the obvious (e.g., `# Set variable` before `VAR=value`)
   - Section headers are acceptable for organizing large files

## Docker Compose Configuration Management

When adding new configurable environment variables to the container:

1. **Update docker-compose.dev.yml**: Add the new environment variable with appropriate development defaults
2. **Update docker-compose.example.yaml**: Add the same environment variable with production-ready defaults and comments explaining its purpose
3. **Update README.md**: Add the new variable to the Configuration section table with description, default value, and usage examples
4. **Document the variable**: Include inline comments describing the variable's purpose, accepted values, and defaults

Example:
```yaml
environment:
  # Token refresh interval in seconds (default: 86400 = 24 hours)
  REFRESH_INTERVAL: "10"  # dev.yml - fast refresh for testing
  # REFRESH_INTERVAL: "86400"  # example.yaml - daily refresh for production
```

## General Guidelines

- Always test changes in the dev environment before documenting production defaults
- Keep environment variable names clear and descriptive
- Use consistent naming conventions across all configuration files
- Ensure backward compatibility when modifying existing configurations