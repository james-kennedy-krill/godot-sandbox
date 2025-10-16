# SupabaseAuth.gd
# Godot 4.x — Autoload this singleton.
# - Email/password sign-in
# - Sign-out (local wipe + optional remote logout)
# - Persist & reload session to user://
# - Auto-refresh access token when expired (refresh_token flow)
extends Node

signal signed_in
signal signed_out

const SUPABASE_URL := "https://deklqsskezgugrmhxpoe.supabase.co"
const SUPABASE_ANON_KEY := "sb_publishable_O1Bo1DEZFpPoSrfn1ZxdOQ_3RD9Jc08"

var supabase_url := SUPABASE_URL
var supabase_anon_key := SUPABASE_ANON_KEY

var access_token: String = ""
var refresh_token: String = ""
var user: Dictionary = {}
var expires_at_unix: int = 0  # epoch seconds when access token expires

const SESSION_FILE := "user://supabase_session.json"

@onready var http := HTTPRequest.new()

func _ready() -> void:
	add_child(http)
	_load_session()

# ---------------------------
# Public API
# ---------------------------

func sign_in(email: String, password: String) -> bool:
	var url := "%s/auth/v1/token?grant_type=password" % supabase_url
	var headers := PackedStringArray([
		"apikey: %s" % supabase_anon_key,
		"Content-Type: application/json",
		"Accept: application/json"
	])
	var body := JSON.stringify({ "email": email, "password": password })

	var res := await _one_shot_request(url, headers, HTTPClient.METHOD_POST, body)
	var code: int = int(res[1])
	var resp_headers: PackedStringArray = res[2]
	var raw: PackedByteArray = res[3]

	if code != 200:
		return false

	var text := raw.get_string_from_utf8()
	if text.strip_edges() == "":
		return false

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var payload: Dictionary = parsed

	if not payload.has("access_token"):
		return false

	_apply_session(payload)
	_save_session()
	return true

func sign_out(remote: bool = false) -> void:
	if remote and access_token != "":
		var url := "%s/auth/v1/logout" % supabase_url
		var headers := PackedStringArray([
			"apikey: %s" % supabase_anon_key,
			"Authorization: Bearer %s" % access_token
		])
		# fire-and-forget; ignore response
		await _one_shot_request(url, headers, HTTPClient.METHOD_POST, "")

	_clear_session()
	_save_session()

func is_authenticated() -> bool:
	return access_token != ""

var _refreshing: bool = false

# Returns true if token exists and isn't (about to be) expired.
# Callers:  var ok := await SupabaseAuth.ensure_fresh_token()
func ensure_fresh_token() -> bool:
	if access_token == "":
		_load_session()
		if access_token == "":
			return false

	# Treat "about to expire" as expired (20s margin).
	if _is_expired(20):
		# De-dupe concurrent refreshes
		if _refreshing:
			# Wait until the in-flight refresh finishes
			while _refreshing:
				await get_tree().process_frame
			# After waiting, check again
			return access_token != "" and not _is_expired(0)

		_refreshing = true
		var ok := await _refresh()
		_refreshing = false
		return ok

	return true

func _is_expired(margin_sec: int = 0) -> bool:
	if access_token == "":
		return true
	var now_unix := int(Time.get_unix_time_from_system())
	return now_unix >= (expires_at_unix - margin_sec)

func auth_headers(include_json: bool = false) -> PackedStringArray:
	var headers: PackedStringArray = [
		"apikey: %s" % supabase_anon_key,
		"Authorization: Bearer %s" % access_token
	]
	if include_json:
		headers.append("Content-Type: application/json")
		headers.append("Accept: application/json")
	return headers

# Convenience helper to make an authenticated REST/RPC call that auto-refreshes on 401.
# Example:
#   var resp = await SupabaseAuth.authed_request(
#       "%s/rest/v1/rpc/record_run" % SupabaseAuth.supabase_url,
#       HTTPClient.METHOD_POST,
#       {"p_level_id": 3, "p_ms": 12750}
#   )
#   if resp.success: print(resp.code, resp.json)
# Replace your existing authed_request with this version
func authed_request(url: String, method: int = HTTPClient.METHOD_GET, body: Variant = null, extra_headers: PackedStringArray = []) -> Dictionary:
	var ok := await ensure_fresh_token()
	if not ok:
		return { "success": false, "code": 0, "json": null, "text": "", "error": "No valid session" }

	var headers := auth_headers(true)
	for h in extra_headers:
		headers.append(h)

	var body_str := ""
	if typeof(body) == TYPE_DICTIONARY or typeof(body) == TYPE_ARRAY:
		body_str = JSON.stringify(body)
	elif typeof(body) == TYPE_STRING:
		body_str = str(body)

	var res := await _one_shot_request(url, headers, method, body_str)
	var code := int(res[1])
	var resp_headers: PackedStringArray = res[2]
	var raw: PackedByteArray = res[3]

	# Retry once on 401 after refresh
	if code == 401 and await _refresh():
		headers = auth_headers(true)
		for h in extra_headers:
			headers.append(h)
		res = await _one_shot_request(url, headers, method, body_str)
		code = int(res[1])
		resp_headers = res[2]
		raw = res[3]

	var text := raw.get_string_from_utf8()

	# parse JSON only if Content-Type is JSON and body not empty
	var ct := ""
	for h in resp_headers:
		if h.to_lower().begins_with("content-type:"):
			ct = h.substr(13).strip_edges().to_lower()
			break
	var json_val: Variant = null
	if text.strip_edges() != "" and ct.findn("application/json") != -1:
		json_val = JSON.parse_string(text)

	return { "success": code >= 200 and code < 300, "code": code, "json": json_val, "text": text, "error": "" }


func _one_shot_request(url: String, headers: PackedStringArray, method: int, body: String) -> Array:
	var h := HTTPRequest.new()
	add_child(h)
	# optional: h.timeout = 30
	var err := h.request(url, headers, method, body)
	if err != OK:
		h.queue_free()
		return [err, 0, PackedStringArray(), PackedByteArray()]
	var res = await h.request_completed  # [result, code, headers, body]
	h.queue_free()
	return res


# ---------------------------
# Internals
# ---------------------------

# Coroutine
func _refresh() -> bool:
	if refresh_token == "":
		return false

	var url := "%s/auth/v1/token?grant_type=refresh_token" % supabase_url
	var headers := PackedStringArray([
		"apikey: %s" % supabase_anon_key,
		"Content-Type: application/json",
		"Accept: application/json"
	])
	var body := JSON.stringify({ "refresh_token": refresh_token })

	var res := await _one_shot_request(url, headers, HTTPClient.METHOD_POST, body)
	var code: int = int(res[1])
	var raw: PackedByteArray = res[3]

	if code != 200:
		_clear_session()
		_save_session()
		return false

	var text := raw.get_string_from_utf8()
	if text.strip_edges() == "":
		_clear_session()
		_save_session()
		return false

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_clear_session()
		_save_session()
		return false
	var payload: Dictionary = parsed

	if not payload.has("access_token"):
		_clear_session()
		_save_session()
		return false

	_apply_session(payload)
	_save_session()
	return true

func _apply_session(payload: Dictionary) -> void:
	access_token = payload.get("access_token", "")
	refresh_token = payload.get("refresh_token", refresh_token)
	user = payload.get("user", {})
	# Compute an absolute expiry timestamp.
	# Supabase returns `expires_in` (seconds). Use a small safety margin.
	var now_unix := int(Time.get_unix_time_from_system())
	var expires_in := int(payload.get("expires_in", 3600))
	expires_at_unix = now_unix + max(60, expires_in - 30)

#func _is_expired() -> bool:
	#if access_token == "":
		#return true
	#var now_unix := int(Time.get_unix_time_from_system())
	#return now_unix >= expires_at_unix

func _clear_session() -> void:
	access_token = ""
	refresh_token = ""
	user = {}
	expires_at_unix = 0

# ---------------------------
# Persistence
# ---------------------------

func _save_session() -> void:
	var f := FileAccess.open(SESSION_FILE, FileAccess.WRITE)
	if f:
		var data := {
			"access_token": access_token,
			"refresh_token": refresh_token,
			"user": user,
			"expires_at_unix": expires_at_unix
		}
		f.store_string(JSON.stringify(data))
		f.close()

func _load_session() -> void:
	if not FileAccess.file_exists(SESSION_FILE):
		return
	var f := FileAccess.open(SESSION_FILE, FileAccess.READ)
	if not f:
		return
	var text := f.get_as_text()
	f.close()
	if text.strip_edges() == "":
		return
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return
	access_token = data.get("access_token", "")
	refresh_token = data.get("refresh_token", "")
	user = data.get("user", {})
	expires_at_unix = int(data.get("expires_at_unix", 0))

# Ensures token is valid AND user object is populated.
# Callers: var ok := await SupabaseAuth.ensure_session_ready()
func ensure_session_ready() -> bool:
	var ok := await ensure_fresh_token()
	if not ok:
		return false

	# If user is missing/empty, fetch it.
	if typeof(user) != TYPE_DICTIONARY or user.is_empty():
		var r := await authed_request("%s/auth/v1/user" % supabase_url, HTTPClient.METHOD_GET)
		if not r.success or typeof(r.json) != TYPE_DICTIONARY:
			return false
		user = r.json
		_save_session()
	return true


func get_display_name(default_val: String = "") -> String:
	var u: Variant = user
	if typeof(u) != TYPE_DICTIONARY:
		return default_val
	var meta: Dictionary = u.get("user_metadata", {})
	var display_name: String = str(meta.get("display_name", ""))
	return display_name.strip_edges()
