extends Node
# Performans Profili - OPTIMIZE.md'ye göre
# Not: class_name kaldırıldı - autoload singleton ile çakışmayı önlemek için
# Godot Profiler + manuel timing

var frame_times: Array[float] = []
var max_samples := 60
var enabled := false

signal performance_warning(message: String)

func _ready() -> void:
	if OS.is_debug_build():
		enabled = true

func _process(_delta: float) -> void:
	if not enabled:
		return
	
	var frame_time = Engine.get_physics_interpolation_fraction()
	frame_times.append(frame_time)
	
	if frame_times.size() > max_samples:
		frame_times.pop_front()
	
	# FPS hesapla
	var avg_frame_time = 0.0
	for ft in frame_times:
		avg_frame_time += ft
	
	if frame_times.size() > 0:
		avg_frame_time /= frame_times.size()
		var fps = 1.0 / avg_frame_time if avg_frame_time > 0 else 0.0
		
		# 60 FPS altına düşerse uyar
		if fps < 55.0:
			performance_warning.emit("FPS düşük: %.1f" % fps)

func measure_function_time(func_name: String, func_call: Callable) -> float:
	if not enabled:
		func_call.call()
		return 0.0
	
	var start_time = Time.get_ticks_usec()
	func_call.call()
	var end_time = Time.get_ticks_usec()
	
	var elapsed_ms = (end_time - start_time) / 1000.0
	if elapsed_ms > 1.0:  # 1ms'den fazla sürerse logla
		print("[Profiler] %s: %.2f ms" % [func_name, elapsed_ms])
	
	return elapsed_ms

func get_collision_pairs() -> int:
	# Physics > Collision Pairs izleme
	# 10k+ spike = darboğaz (OPTIMIZE.md)
	return PhysicsServer2D.get_process_info(PhysicsServer2D.INFO_ACTIVE_OBJECTS)

func get_draw_calls() -> int:
	# Rendering > Draw Calls
	# Godot 4.5'te doğru sabit adı
	return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
