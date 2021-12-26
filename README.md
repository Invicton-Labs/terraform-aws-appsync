# Terraform AWS AppSync

This module creates a complete AppSync deployment, including the GraphQL API, the schema, and the resolvers. It is intended to be used with the [Invicton-Labs/appsync-parser](https://registry.terraform.io/modules/Invicton-Labs/appsync-parser/aws/latest) module.

## Note

To change a datasource's name (handled outside of this module), you must:

1. Have `create_before_destroy = true` in a `lifecycle` block for that datasource
2. `terraform taint` the old datasource

Otherwise, it will fail to change the datasource name because resolvers are linked to it.