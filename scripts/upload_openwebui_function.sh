#!/usr/bin/env bash

################################################################################
# This is a helper script to upload a function through Open WebUI.
################################################################################

# Function to parse CLI arguments
parse_args() {
    # Initialize default values
    open_webui_url="http://localhost:8080"
    function_file=""
    function_name=""
    description=""
    valves=""

    # Process each argument
    while [[ $# > 0 ]]; do
        case "$1" in
            -u|--open-webui-url)
                open_webui_url="$2"
                shift
                ;;
            -f|--function-file)
                function_file="$2"
                shift
                ;;
            -n|--function-name)
                function_name="$2"
                shift
                ;;
            -d|--description)
                description="$2"
                shift
                ;;
            -v|--valves)
                valves="$2"
                shift
                ;;
            *) # Unknown option, handle error
                echo "Error: Unknown option '$1'"
                echo "Usage: $0 [--open-webui-url URL] --function-file FILE_PATH [-d DESCRIPTION]"
                exit 1
                ;;
        esac
        shift
    done

    if [ -z "$function_file" ]; then
        echo "Error: --function-file is required."
        exit 1
    fi
    if [ "$function_name" == "" ]; then
        function_name=$(basename $function_file | rev | cut -d'.' -f 2- | rev | sed 's,[_-], ,g')
    fi
    function_id=$(echo "$function_name" | sed 's, ,_,g')
    api_base_url=$(echo "$open_webui_url" | sed 's,/$,,g')/api/v1
}

# Call the function to parse arguments
parse_args "$@"
echo "Open Webui URL: $open_webui_url"
echo "Open Webui API URL: $api_base_url"
echo "Function File Path: $function_file"
echo "Function Name: $function_name"
echo "Function ID: $function_id"
echo "Description: $description"

# Sign in and get a token
# NOTE: This assumes running without auth!
token=$(curl -s $api_base_url/auths/signin \
    -XPOST \
    -H "Content-Type: application/json" \
    -d'{"email": "", "password": ""}' | jq -r .token)

function api_call {
    endpoint=$1
    shift
    method=$1
    shift
    curl -s ${api_base_url}/$endpoint \
        -X $method \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $token" "$@"
}

function function_exists {
    api_call functions/id/$1 GET -v 2>&1 | grep "HTTP/[^ ]* 200 OK" &>/dev/null
}

function function_active {
    api_call functions/id/$1 GET | jq -r ".is_active"
}

# Check to see if the function already exists
if function_exists $function_id; then
    echo "Function [$function_id] already exists!"
    post_endpoint="functions/id/$function_id/update"
else
    echo "Function [$function_id] doesn't exist!"
    post_endpoint="functions/create"
fi

# Create the function
body=$(python -c "import json; print(json.dumps({
    \"id\":\"$function_id\",
    \"name\": \"$function_name\",
    \"content\": open(\"$function_file\", \"r\").read(),
    \"meta\": {
        \"description\": \"$description\",
        \"manifest\": {
            \"requirements\": \"beeai-sdk\"
        }
    }
}))")

api_call $post_endpoint POST -d"$body"

# Make sure the function is toggled on
if [ "$(function_active $function_id)" == "false" ]
then
    api_call functions/id/$function_id/toggle POST
fi

# If Valves given, configure them
if [ "$valves" != "" ]
then
    api_call functions/id/$function_id/valves/update POST -d"$valves"
fi
