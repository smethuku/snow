import json
import snowflake.connector
from typing import Dict, List, Any
import os
from tabulate import tabulate

# Configuration
STATE_FILE_PATH = "/path/to/your/terraform/state/terraform.tfstate"  # Replace with path to your local state file
RESOURCE_CONFIG_PATH = "Resource-attributes.json"  # Path to resource attributes JSON file
SNOWFLAKE_ACCOUNT = os.getenv("SNOWFLAKE_ACCOUNT")
SNOWFLAKE_USER = os.getenv("SNOWFLAKE_USER")
SNOWFLAKE_PASSWORD = os.getenv("SNOWFLAKE_PASSWORD")
SNOWFLAKE_ROLE = "your_role"  # Replace with your Snowflake role
SNOWFLAKE_WAREHOUSE = "your_warehouse"  # Replace with your Snowflake warehouse

def load_resource_config() -> List[Dict[str, Any]]:
    """
    Load the resource configuration from Resource-attributes.json.
    """
    try:
        if not os.path.exists(RESOURCE_CONFIG_PATH):
            raise RuntimeError(f"Resource config file not found at: {RESOURCE_CONFIG_PATH}")
        with open(RESOURCE_CONFIG_PATH, "r") as f:
            return json.load(f)
    except json.JSONDecodeError:
        raise RuntimeError("Failed to parse Resource-attributes.json")
    except Exception as e:
        raise RuntimeError(f"Error reading resource config file: {str(e)}")

def get_terraform_state() -> Dict[str, Any]:
    """
    Read the local Terraform state file in JSON format.
    """
    try:
        if not os.path.exists(STATE_FILE_PATH):
            raise RuntimeError(f"Terraform state file not found at: {STATE_FILE_PATH}")
        with open(STATE_FILE_PATH, "r") as f:
            return json.load(f)
    except json.JSONDecodeError:
        raise RuntimeError("Failed to parse Terraform state file JSON")
    except Exception as e:
        raise RuntimeError(f"Error reading Terraform state file: {str(e)}")

def get_snowflake_resources(resource: str) -> List[Dict[str, Any]]:
    """
    Query Snowflake for the specified resource type and return relevant attributes.
    """
    try:
        conn = snowflake.connector.connect(
            user=SNOWFLAKE_USER,
            password=SNOWFLAKE_PASSWORD,
            account=SNOWFLAKE_ACCOUNT,
            role=SNOWFLAKE_ROLE,
            warehouse=SNOWFLAKE_WAREHOUSE
        )
        cursor = conn.cursor()

        if resource == "Warehouse":
            cursor.execute("SHOW WAREHOUSES")
            resources = [
                {
                    "name": row[0],
                    "warehouse_size": row[2] if row[2] else "X-SMALL",  # Default size
                    "warehouse_type": row[1] if row[1] else "STANDARD",  # Default type
                    "comment": row[10] if row[10] else ""  # Handle NULL comments
                }
                for row in cursor.fetchall()
            ]
        elif resource == "Database":
            cursor.execute("SHOW DATABASES")
            resources = [
                {
                    "name": row[1],
                    "data_retention_time_in_days": row[9] if row[9] is not None else 1,  # Default retention
                    "comment": row[4] if row[4] else ""  # Handle NULL comments
                }
                for row in cursor.fetchall()
            ]
        else:
            raise RuntimeError(f"Unsupported resource type: {resource}")

        cursor.close()
        conn.close()
        return resources
    except snowflake.connector.errors.Error as e:
        raise RuntimeError(f"Failed to query Snowflake {resource}s: {str(e)}")

def compare_resources(tf_state: Dict[str, Any], sf_resources: List[Dict[str, Any]], resource: str, attributes: List[str]) -> List[Dict[str, Any]]:
    """
    Compare Terraform state with Snowflake resources for the specified resource type and attributes.
    """
    drifts = []
    tf_resource_type = f"snowflake_{resource.lower()}"

    # Extract resources from Terraform state
    tf_resources = []
    for res in tf_state.get("resources", []):
        if res["type"] == tf_resource_type:
            tf_resources.extend([instance["attributes"] for instance in res["instances"]])

    # Create dictionaries for comparison
    tf_res_map = {res["name"]: res for res in tf_resources}
    sf_res_map = {res["name"]: res for res in sf_resources}

    # Compare resources
    for res_name in set(tf_res_map.keys()) | set(sf_res_map.keys()):
        if res_name not in tf_res_map:
            drifts.append({
                "resource": tf_resource_type,
                "name": res_name,
                "drift": "Exists in Snowflake but not in Terraform"
            })
        elif res_name not in sf_res_map:
            drifts.append({
                "resource": tf_resource_type,
                "name": res_name,
                "drift": "Exists in Terraform but not in Snowflake"
            })
        else:
            # Compare specified attributes
            tf_res = tf_res_map[res_name]
            sf_res = sf_res_map[res_name]
            for attr in attributes:
                tf_value = tf_res.get(attr, "" if attr == "comment" else "X-SMALL" if attr == "warehouse_size" else "STANDARD" if attr == "warehouse_type" else 1)
                sf_value = sf_res.get(attr, "" if attr == "comment" else "X-SMALL" if attr == "warehouse_size" else "STANDARD" if attr == "warehouse_type" else 1)
                # Normalize case for warehouse_size and warehouse_type
                if attr in ["warehouse_size", "warehouse_type"]:
                    tf_value = str(tf_value).upper()
                    sf_value = str(sf_value).upper()
                if tf_value != sf_value:
                    drifts.append({
                        "resource": tf_resource_type,
                        "name": res_name,
                        "drift": f"{attr} mismatch (Terraform: '{tf_value}', Snowflake: '{sf_value}')"
                    })

    return drifts

def main():
    try:
        # Load resource configuration
        print("Loading resource configuration...")
        resource_config = load_resource_config()

        # Read local Terraform state
        print("Reading local Terraform state...")
        tf_state = get_terraform_state()

        # Process each resource type
        for res_config in resource_config:
            resource = res_config["Resource"]
            attributes = res_config["Attributes"]
            print(f"\nQuerying Snowflake {resource}s...")
            sf_resources = get_snowflake_resources(resource)
            print(f"Comparing {resource}s...")
            drifts = compare_resources(tf_state, sf_resources, resource, attributes)

            # Prepare table output
            if drifts:
                table = []
                for drift in drifts:
                    table.append([drift["name"], drift["drift"]])
                print(f"\n{resource} Drift Table:")
                print(tabulate(table, headers=["Name", "Drift"], tablefmt="grid"))
            else:
                print(f"\nNo drift detected for {resource}s.")

    except RuntimeError as e:
        print(f"Error: {str(e)}")
    except Exception as e:
        print(f"Unexpected error: {str(e)}")

if __name__ == "__main__":
    main()
