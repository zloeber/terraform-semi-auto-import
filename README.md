# terraform-semi-auto-import

This makes creating import blocks for your terraform manifests a bit easier.

# Use Case

You have created a slew of terraform modules or code for resources that already exist and would like to import them into your state via terraform `import` blocks.

# Why No Auto Import?

For a long time I've wondered why terraform does not include a native ability to automatically import targeted state elements. It 'feels' like it would be such a killer feature to have when you need to refactor a bunch of infrastructure as code or add it where none existed before. But a deeper inspection on this yields several reasons that this feature will never be added.

## 1. Ambiguity

Terraform relies on explicit code definitions in `.tf` files to know what resources to manage.

Auto-import would require Terraform to guess the appropriate HCL configuration for each resource. This would be error-prone or incomplete, especially for:

- Resources with complex dependencies
- Resources using computed values, modules, or for_each/count
- Custom logic or dynamic blocks

## 2. Lack of 1:1 Mapping from API → HCL

Many cloud resources have non-obvious or lossy mappings between API responses and HCL syntax.

> **Example**: AWS IAM policies, ECS task definitions, security group rules, etc., may include generated or optional data not present in Terraform configs.

Some fields are ignored by Terraform or only exist as computed outputs, meaning Terraform can't regenerate full HCL from state.

Analogy: It's like trying to reverse-engineer source code from a compiled binary — possible in some cases, but often messy.

## 3. Tooling Complexity

Implementing robust auto-import across providers would require:

- Parsing provider schemas for every resource type
- Generating idiomatic HCL, including nested blocks
- Ensuring generated code matches best practices
- Handling drift or manual configuration inconsistencies

This is difficult to maintain across hundreds of providers and thousands of resource types.

## 4. Risk of State Drift or Mismanagement

Automatically importing resources could lead to:

- Accidental overwrites of unmanaged resources
- Misalignment between actual infrastructure and expectations in code
- Users thinking resources are safely managed when they aren't

Terraform's import is deliberately manual and opt-in to prevent such surprises.

## 5. Terraform's Design Philosophy: Explicit is Better

HashiCorp prefers a conservative, explicit workflow where users:

- Define resources in HCL
- Import them manually using terraform import
- Verify state and code alignment

This makes changes and intentions clear, especially in regulated or production environments.

# So What? I Need This!

We can use terrform's built in import blocks to perform one-time state imports but doing so manually is a slog. As such we can use a code generation approach against an existing plan file (in json) to emit all the import statements for new resources you know already exist. This can be done with clever mapping in some cases and the process works like this:

1. Create the initial terraform manifests
2. `terraform init`
3. `terraform plan -out=plan.tfplan`
4. `terraform show -no-color -json plan.tfplan | jq > plan.json`
5. Look up the import schema to determine how the import id is formatted and if you already have all the data you need to construct the id in your existing plan file.
6. Create an id map for your import data. This should target one or more providers and can include any known data you already have or that can be scraped from the existing plan file.
7. Run the included script with your plan json data and the map file to create a new set of import commands. `uv run ./import-terraform.py ./plan.json new_imports.tf --id-map ./import_map.yaml`
8. `terraform plan -out=plan.tfplan` --> If this shows only imports and additions then you likely are ready to apply. If not, then review what went wrong or how your mappings are defined to ensure they are accurate.

> **NOTE 1** In step 4 I use jq to make nice output to parse later for making your map file.
> **NOTE 2** Each map file is going to be highly dependant on your needs. I've yet to figure out how to import the appropriate schema to automate this process for a target provider.

## Details

This script reads the `resource_changes` dictionary of the plan file for anything with `change.action` == `create`. For each of the created resources it then looks up the provider for the resource then if that provider exists in your map file, it looks up the resource type itself for a mapping definition. If found, it attempts to extrapolate the it map based on the same created resource's `change.after` data.
## Requirements

Install requirements via uv: `uv sync`

You can also use mise to install terraform and python and uv if required `mise install -y` (also included in `./configure.sh`)

## Example

A fairly poor but working example of how to do this can be found in the `./example` path. Local resources do not lend themselves well to importing state so I used a local vault deployment with the hashicorp/vault terraform provider instead. This is what you can do to run it:

```bash
# Start local vault dev instance
docker compose up -d

# export the dev root token
export VAULT_TOKEN=dev-token-12345

# perform initial deployment

terraform init
terraform plan -out plan.tfplan
terraform apply plan.tfplan

# delete the local state then get your plan as json again.
rm ./terraform.tfstate ./terraform.tfstate.backup
terraform show -no-color -json plan.tfplan | jq > plan.json
```

At this point you will need to figure out the import id by visiting the terraform provider documentation (I know of no way to scrape this automatically anywhere). So I dropped into the terraform provider [website](https://registry.terraform.io/providers/hashicorp/vault/latest) for vault and looked up the `vault_mount` and `vault_kv_secret_v2` resources to see that they both required just a path to import. Sweet! We then inspect the plan json output for the  vault_mount create resource data and zero in on the `after` section:

```json
{
      "address": "vault_mount.kv",
      "mode": "managed",
      "type": "vault_mount",
      "name": "kv",
      "provider_name": "registry.terraform.io/hashicorp/vault",
      "change": {
        "actions": [
          "create"
        ],
        "before": null,
        "after": {
          "allowed_managed_keys": null,
          "allowed_response_headers": null,
          "delegated_auth_accessors": null,
          "description": "KV Version 2 secret engine",
          "external_entropy_access": false,
          "identity_token_key": null,
          "listing_visibility": null,
          "local": null,
          "namespace": null,
          "options": {
            "version": "2"
          },
          "passthrough_request_headers": null,
          "path": "kv",
          "plugin_version": null,
          "type": "kv"
        },
        ...
```

Looks like they give us `path` straight away so the start of our map file looks like this:

```yaml
registry.terraform.io/hashicorp/vault:
  vault_mount:
    id: "{path}"
```

Now if we look at the next resource we see something like this:

```json
{
      "address": "vault_kv_secret_v2.secrets[\"user-credentials\"]",
      "mode": "managed",
      "type": "vault_kv_secret_v2",
      "name": "secrets",
      "index": "user-credentials",
      "provider_name": "registry.terraform.io/hashicorp/vault",
      "change": {
        "actions": [
          "create"
        ],
        "before": null,
        "after": {
          "cas": null,
          "data_json": "{\"admin_password\":\"secure_password_123\",\"admin_username\":\"admin\",\"last_backup\":\"2024-01-15T10:30:00Z\",\"user_count\":\"150\"}",
          "data_json_wo": null,
          "data_json_wo_version": null,
          "delete_all_versions": false,
          "disable_read": false,
          "mount": "kv",
          "name": "user-credentials",
          "namespace": null,
          "options": null
        },
        ...
```

No path! But we can make it with `mount` and `name` so that becomes our mapping to complete our map file.

```yaml
registry.terraform.io/hashicorp/vault:
  vault_mount:
    id: "{path}"
  vault_kv_secret_v2:
    id: "{mount}/data/{name}"
```

> **NOTE:** An astute reader will notice that I included the 'data' section in that path. This is just a nuance of Vault kv version 2 that I happen to know already. It is also a good example of how you can manually tweak these mappings I suppose.

Now that we have this we can create the import block file and proceed to replan with it in place to import all the existing paths.

```bash
uv run ../import-terraform.py ./plan.json kv_imports.tf --id-map ./import_map.yaml
terraform plan -out plan.tfplan
terraform apply plan.tfplan
```

This will pull in the existing secrets as state and recreate your state file as it was before you deleted it.
