# Render explicitly typed environment placeholders as YAML or Lua string
# literals. Each replacement is appended to the result without being scanned
# again, so characters in a value are always data, never template syntax.
# Run with LC_ALL=C: UTF-8 byte comparisons must not use locale collation.

function quote_string(value, format, result, i, char) {
    result = "\""
    for (i = 1; i <= length(value); i++) {
        char = substr(value, i, 1)
        if (char == "\\") result = result "\\\\"
        else if (char == "\"") result = result "\\\""
        else if (char == "\n") result = result "\\n"
        else if (char == "\r") result = result "\\r"
        else if (char == "\t") result = result "\\t"
        else if (format == "yaml" && substr(value, i, length("\302\205")) == "\302\205") {
            # YAML treats a literal Unicode NEL as a line break even in quotes.
            result = result "\\u0085"
            i += length("\302\205") - 1
        }
        else if (char in controls) {
            if (format == "lua") result = result sprintf("\\%03d", controls[char])
            else result = result sprintf("\\u%04x", controls[char])
        } else result = result char
    }
    return result "\""
}

BEGIN {
    for (i = 1; i < 32; i++) controls[sprintf("%c", i)] = i
    controls[sprintf("%c", 127)] = 127

    if (gateway == "kong") {
        # Keep user-session JWTs intact, translate configured opaque API keys,
        # and otherwise retain legacy apikey passthrough.
        auth = "$((headers.authorization ~= nil and headers.authorization:sub(1, 10) ~= 'Bearer sb_' and headers.authorization)"
        if (ENVIRON["SUPABASE_SECRET_KEY"] != "" && ENVIRON["SUPABASE_PUBLISHABLE_KEY"] != "") {
            secret = quote_string(ENVIRON["SUPABASE_SECRET_KEY"], "lua")
            publishable = quote_string(ENVIRON["SUPABASE_PUBLISHABLE_KEY"], "lua")
            service_jwt = quote_string(ENVIRON["SERVICE_ROLE_KEY_ASYMMETRIC"], "lua")
            anon_jwt = quote_string(ENVIRON["ANON_KEY_ASYMMETRIC"], "lua")
            auth = auth " or (headers.apikey == " secret " and " quote_string("Bearer " ENVIRON["SERVICE_ROLE_KEY_ASYMMETRIC"], "lua") ")"
            auth = auth " or (headers.apikey == " publishable " and " quote_string("Bearer " ENVIRON["ANON_KEY_ASYMMETRIC"], "lua") ")"
            websocket = "$((query_params.apikey == " secret " and " service_jwt ") or (query_params.apikey == " publishable " and " anon_jwt ") or query_params.apikey)"
        } else {
            websocket = "$(query_params.apikey)"
        }
        auth = auth " or headers.apikey)"
        values["LUA_AUTH_HEADER"] = "Authorization: " auth
        values["LUA_RT_WS_HEADER"] = "x-api-key:" websocket
        values["LUA_RT_WS_QUERY"] = "apikey:" websocket
    }
}

{
    result = ""
    rest = $0
    while (match(rest, /\$\{[A-Z_][A-Z_0-9]*:(yaml|lua)\}/)) {
        token = substr(rest, RSTART + 2, RLENGTH - 3)
        separator = index(token, ":")
        name = substr(token, 1, separator - 1)
        format = substr(token, separator + 1)
        value = (name in values) ? values[name] : ENVIRON[name]
        result = result substr(rest, 1, RSTART - 1) quote_string(value, format)
        rest = substr(rest, RSTART + RLENGTH)
    }
    print result rest
}
