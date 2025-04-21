# /// script
# requires-python = ">=3.11,<3.12"
# ///

import sys
import json

print(json.dumps({
    "id":sys.argv[1],
    "name": sys.argv[2],
    "content": open(sys.argv[3], "r").read(),
    "meta": {
        "description": sys.argv[4],
        "manifest": {
            "requirements": "beeai-sdk"
        }
    }
}))