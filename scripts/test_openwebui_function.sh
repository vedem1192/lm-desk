#!/usr/bin/env bash

################################################################################
# This is a helper script to test a function through Open WebUI. It does the
# following:
#
# 1. Upload the function to Open WebUI
# 2. Validate that the function is visible
# 3. Call the function with a sample request
# 4. Delete the function
################################################################################

# Function to parse CLI arguments
parse_args() {
    # Initialize default values
    open_webui_url="http://localhost:8080"
    function_file=""
    request="why is the sky blue?"
    function_name=""

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
            -r|--request)
                request="$2"
                shift
                ;;
            -n|--function-name)
                function_name="$2"
                shift
                ;;
            *) # Unknown option, handle error
                echo "Error: Unknown option '$1'"
                echo "Usage: $0 [--open-webui-url URL] --function-file FILE_PATH [-r REQUEST]"
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
echo "Request: $request"
echo "Function Name: $function_name"
echo "Function ID: $function_id"

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
    curl -s ${api_base_url}/$endpoint -X $method -H "Authorization: Bearer $token" "$@"
}

function function_exists {
    api_call functions/id/$1 GET -v 2>&1 | grep "HTTP/[^ ]* 200 OK" &>/dev/null
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
        \"manifest\": {
            \"requirements\": \"beeai-sdk\"
        }
    }
}))")
api_call $post_endpoint POST -H "Content-Type: application/json" -d"$body" -v
