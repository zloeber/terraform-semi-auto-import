#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# This script is used to generate Terraform import statements
# based on a Terraform plan JSON file. It reads the plan file,
# identifies resources that are set to be created, and generates
# import blocks for those resources using a provided ID mapping file.

import json

import click
import yaml


def extract_value_from_dict(data, key_path):
    """
    Recursively extracts a value from a nested dictionary using a string-based key path.
    """
    try:
        return eval(key_path, {}, {"__builtins__": {}, "data": data})
    except KeyError as e:
        raise KeyError(f"Missing key in data: {e}") from e
    except Exception as e:
        raise ValueError(f"Invalid key path: {key_path}") from e


def eval_fstring(non_f_str: str):
    return eval(f'f"""{non_f_str}"""')


def extrapolate_template(template: str, data: dict) -> str:
    """
    Replaces placeholders in the template with corresponding values from the dictionary.
    """
    while "{" in template and "}" in template:
        start = template.find("{")
        end = template.find("}", start) + 1
        if start == -1 or end == 0:
            break

        placeholder = template[start:end]
        key_path = placeholder.strip("{}")

        value = extract_value_from_dict(data, key_path)
        template = template.replace(placeholder, str(value), 1)

    return template


def parse_terraform_plan_for_created_resources(plan_file):
    """Parse the Terraform plan JSON and extract resources that need to be imported."""
    with open(plan_file, "r") as file:
        plan_data = json.load(file)

    created_resources = []
    for resource in plan_data.get("resource_changes", []):
        if resource.get("change", {}).get("actions") == ["create"]:
            created_resources.append(resource)

    return created_resources


def generate_import_blocks(resources, id_map: dict = None):
    """
    Generate Terraform import blocks for the given resources and a mapping file like:
    registry.terraform.io/hashicorp/aws:
      aws_ssoadmin_application_assignment:
        id: "{change['after']['application_arn']},{change['after']['principal_id']},{change['after']['principal_type']}"
    """
    import_statements = []

    for resource in resources:
        provider_name = resource.get("provider_name")
        resource_type = resource.get("type")
        resource_name = resource.get("name")
        resource_address = resource.get("address")
        if provider_name in id_map:
            resource_id_map = id_map[provider_name][resource_type]["id"]
            if resource_id_map:
                extrapolated_id = resource_id_map.format(**resource["change"]["after"])
                import_block = (
                    f"import {{\n"
                    f"  to = {resource_address}\n"
                    f'  id = "{extrapolated_id}"\n'
                    f"}}\n"
                )
                import_statements = import_statements + [import_block]
        else:
            continue

    return import_statements


@click.command()
@click.argument("plan_file", type=click.Path(exists=True))
@click.argument("output_file", type=click.Path(), default=None)
@click.option(
    "--id-map",
    required=True,
    type=click.Path(exists=True),
    help="Path to the ID map file.",
)
def generate_imports(plan_file, output_file, id_map):
    """Generate Terraform import statements from a plan JSON file."""
    with open(id_map, "r") as file:
        id_mapping = yaml.safe_load(file)

    resources = parse_terraform_plan_for_created_resources(plan_file)
    import_statements = generate_import_blocks(resources, id_map=id_mapping)

    # Write the import statements to the output file
    if output_file is None:
        for statement in import_statements:
            click.echo(statement)
    else:
        with open(output_file, "w") as file:
            file.write("\n".join(import_statements))
            click.echo(f"Terraform import statements written to {output_file}")


if __name__ == "__main__":
    generate_imports()
