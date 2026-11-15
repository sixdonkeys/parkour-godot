extends RefCounted
## Memory instrument: process resident memory plus video memory
## (ARCHITECTURE.md, Measured events; decision verification-rendering).
## Each operating system reports resident size differently; every branch
## falls back to -1 rather than guessing.


static func process_rss_bytes() -> int:
	match OS.get_name():
		"Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			var f := FileAccess.open("/proc/self/statm", FileAccess.READ)
			if f:
				var parts := f.get_line().split(" ")  # /proc files report length 0, so read a line
				if parts.size() > 1:
					return int(parts[1]) * _page_size()
		"macOS":
			var out: Array = []
			if OS.execute("ps", ["-o", "rss=", "-p", str(OS.get_process_id())], out) == 0 and not out.is_empty():
				return int(String(out[0]).strip_edges()) * 1024
		"Windows":
			var out2: Array = []
			if OS.execute("tasklist", ["/FI", "PID eq %d" % OS.get_process_id(), "/FO", "CSV", "/NH"], out2) == 0 and not out2.is_empty():
				var cols := String(out2[0]).split("\",\"")
				if cols.size() >= 5:
					return int(cols[4].replace(",", "").replace(".", "").replace(" K\"", "").replace("K", "").strip_edges()) * 1024
	return -1


static func _page_size() -> int:
	# Linux on Apple silicon (Asahi) uses 16 KiB pages; most x86_64 kernels 4 KiB.
	var out: Array = []
	if OS.execute("getconf", ["PAGESIZE"], out) == 0 and not out.is_empty():
		var v := int(String(out[0]).strip_edges())
		if v > 0:
			return v
	return 4096


static func reading(label: String) -> Dictionary:
	var rss := process_rss_bytes()
	var vid := int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
	return {
		"label": label,
		"process_rss_bytes": rss,
		"video_bytes": vid,
		"texture_bytes": int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)),
		"buffer_bytes": int(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)),
		"static_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"total_bytes": (rss + vid) if rss >= 0 else -1,
		"usec": Time.get_ticks_usec(),
	}
