extends IProgressBackend
class_name SupabaseProgressBackend

func save_run(level_id: int, ms: int) -> void:
	# Your RPC from earlier:
	var url := "%s/rest/v1/rpc/record_run" % SupabaseAuth.supabase_url
	var body := { "p_level_id": level_id, "p_ms": ms }
	var _resp := await SupabaseAuth.authed_request(url, HTTPClient.METHOD_POST, body)
	# Ignore result here; you can add logging if needed.

func get_my_best(level_id: int) -> int:
	var uid := str(SupabaseAuth.user.get("id", ""))
	if uid == "": return -1
	var url := "%s/rest/v1/user_best_times?select=best_ms&level_id=eq.%d&user_id=eq.%s&order=best_ms.asc&limit=1" \
		% [SupabaseAuth.supabase_url, level_id, uid]
	var resp := await SupabaseAuth.authed_request(url, HTTPClient.METHOD_GET, null, ["Accept: application/json"])
	if resp.success and typeof(resp.json) == TYPE_ARRAY and resp.json.size() > 0:
		return int(resp.json[0].get("best_ms", -1))
	return -1

func get_level_top5(level_id: int) -> Array:
	var url := "%s/rest/v1/level_top5?select=level_id,user_id,best_ms,achieved_at&level_id=eq.%d&order=best_ms.asc,achieved_at.asc" \
		% [SupabaseAuth.supabase_url, level_id]
	var resp := await SupabaseAuth.authed_request(url, HTTPClient.METHOD_GET, null, ["Accept: application/json"])
	return resp.json if resp.success and typeof(resp.json) == TYPE_ARRAY else []

func get_level_top5_named(level_id: int) -> Array:
	var url := "%s/rest/v1/level_top5_named?select=level_id,user_id,display_name,best_ms,achieved_at&level_id=eq.%d&order=best_ms.asc,achieved_at.asc" \
		% [SupabaseAuth.supabase_url, level_id]
	var resp := await SupabaseAuth.authed_request(url, HTTPClient.METHOD_GET, null, ["Accept: application/json"])
	return resp.json if resp.success and typeof(resp.json) == TYPE_ARRAY else []

# --- PROGRESS API ---

func save_progress(last_level: int) -> void:
	var uid := str(SupabaseAuth.user.get("id", ""))
	if uid == "":
		return
	var url := "%s/rest/v1/progress" % SupabaseAuth.supabase_url
	var body := [{ "user_id": uid, "last_level": last_level }]
	var extra := PackedStringArray(["Prefer: resolution=merge-duplicates,return=representation"])
	var _resp := await SupabaseAuth.authed_request(url, HTTPClient.METHOD_POST, body, extra)
	# ignore response; you can add logging if desired

func load_progress() -> Dictionary:
	var uid := str(SupabaseAuth.user.get("id", ""))
	if uid == "":
		return {}
	var url := "%s/rest/v1/progress?select=last_level,updated_at&user_id=eq.%s&limit=1" % [SupabaseAuth.supabase_url, uid]
	var resp := await SupabaseAuth.authed_request(url, HTTPClient.METHOD_GET, null, ["Accept: application/json"])
	if resp.success and typeof(resp.json) == TYPE_ARRAY and resp.json.size() > 0:
		return { "last_level": int(resp.json[0].get("last_level", -1)), "played": true }
	return {}

func has_progress() -> bool:
	var uid := str(SupabaseAuth.user.get("id", ""))
	if uid == "":
		return false
	var url := "%s/rest/v1/progress?select=user_id&user_id=eq.%s&limit=1" % [SupabaseAuth.supabase_url, uid]
	var resp := await SupabaseAuth.authed_request(url, HTTPClient.METHOD_GET, null, ["Accept: application/json"])
	return resp.success and typeof(resp.json) == TYPE_ARRAY and resp.json.size() > 0

func reset_progress() -> void:
	var uid := str(SupabaseAuth.user.get("id", ""))
	if uid == "":
		return
	var url := "%s/rest/v1/progress?user_id=eq.%s" % [SupabaseAuth.supabase_url, uid]
	var _resp := await SupabaseAuth.authed_request(url, HTTPClient.METHOD_DELETE)
