extends Node
# Font Manager - Sayılar için Bake Soda, yazılar için Noto Sans

var number_font: FontFile = null
var text_font: FontFile = null
var text_font_bold: FontFile = null  # Butonlar için bold font

func _ready() -> void:
	# Font'ları yükle (bir frame sonra tekrar dene - import için)
	call_deferred("_load_fonts")

func _load_fonts() -> void:
	# Sayılar için Bake Soda fontunu yükle
	var bake_soda_path = "res://assets/font/Bake Soda.otf"
	if ResourceLoader.exists(bake_soda_path):
		var loaded = load(bake_soda_path)
		if loaded is FontFile:
			number_font = loaded as FontFile
			print("FontManager: Bake Soda fontu yüklendi (sayılar için) - Path: ", number_font.resource_path if number_font.resource_path else "unknown")
		else:
			print("FontManager: Bake Soda fontu yüklenemedi, tip: ", loaded.get_class() if loaded else "null")
	else:
		print("FontManager: Bake Soda font dosyası bulunamadı: ", bake_soda_path)
	
	# Yazılar için Noto Sans fontunu yükle
	var noto_sans_path = "res://assets/font/NotoSans-Regular.ttf"
	if ResourceLoader.exists(noto_sans_path):
		var loaded = load(noto_sans_path)
		if loaded is FontFile:
			text_font = loaded as FontFile
			print("FontManager: Noto Sans fontu yüklendi (yazılar için) - Path: ", text_font.resource_path if text_font.resource_path else "unknown")
		else:
			print("FontManager: Noto Sans fontu yüklenemedi, tip: ", loaded.get_class() if loaded else "null", " - Path: ", noto_sans_path)
	else:
		print("FontManager: Noto Sans font dosyası bulunamadı: ", noto_sans_path)
	
	# Butonlar için Noto Sans Bold fontunu yükle
	var noto_sans_bold_path = "res://assets/font/NotoSans-Bold.ttf"
	if ResourceLoader.exists(noto_sans_bold_path):
		var loaded = load(noto_sans_bold_path)
		if loaded is FontFile:
			text_font_bold = loaded as FontFile
			print("FontManager: Noto Sans Bold fontu yüklendi (butonlar için) - Path: ", text_font_bold.resource_path if text_font_bold.resource_path else "unknown")
		else:
			print("FontManager: Noto Sans Bold fontu yüklenemedi, tip: ", loaded.get_class() if loaded else "null", " - Path: ", noto_sans_bold_path)
	else:
		print("FontManager: Noto Sans Bold font dosyası bulunamadı: ", noto_sans_bold_path)

func get_number_font() -> FontFile:
	return number_font

func get_text_font() -> FontFile:
	return text_font

func is_number_only(text: String) -> bool:
	# Sadece sayılar ve boşluk içeriyor mu kontrol et
	if text.is_empty():
		return false
	
	# Sayılar, boşluk, nokta, virgül, eksi işareti içerebilir
	var number_pattern = RegEx.new()
	number_pattern.compile("^[0-9\\s\\.\\-\\,]+$")
	return number_pattern.search(text) != null

func apply_font_to_label(label: Label) -> void:
	if not label:
		return
	
	var text = label.text
	var font_to_use: FontFile = null
	
	if is_number_only(text):
		# Sadece sayı içeriyorsa Bake Soda kullan
		font_to_use = number_font
		if not font_to_use and text_font:
			font_to_use = text_font  # Fallback
	else:
		# Yazı içeriyorsa Noto Sans kullan
		font_to_use = text_font
		if not font_to_use and number_font:
			font_to_use = number_font  # Fallback
	
	if font_to_use:
		label.add_theme_font_override("font", font_to_use)
		print("FontManager: Font uygulandı - Label: '", text, "' Font: ", font_to_use.resource_path if font_to_use.resource_path else "unknown")
	else:
		print("FontManager: Font bulunamadı - Label: '", text, "' (number_font: ", number_font != null, ", text_font: ", text_font != null, ")")

func apply_font_to_button(button: Button) -> void:
	if not button:
		return
	
	var text = button.text
	var font_to_use: FontFile = null
	
	if is_number_only(text):
		# Sadece sayı içeriyorsa Bake Soda kullan
		font_to_use = number_font
		if not font_to_use and text_font:
			font_to_use = text_font  # Fallback
	else:
		# Yazı içeriyorsa Noto Sans Bold kullan (butonlar için)
		font_to_use = text_font_bold
		if not font_to_use and text_font:
			font_to_use = text_font  # Fallback to regular
		if not font_to_use and number_font:
			font_to_use = number_font  # Fallback
	
	if font_to_use:
		button.add_theme_font_override("font", font_to_use)
		print("FontManager: Font uygulandı - Button: '", text, "' Font: ", font_to_use.resource_path if font_to_use.resource_path else "unknown")
	else:
		print("FontManager: Font bulunamadı - Button: '", text, "' (number_font: ", number_font != null, ", text_font: ", text_font != null, ", text_font_bold: ", text_font_bold != null, ")")

func apply_fonts_recursive(node: Node) -> void:
	# Recursive olarak tüm label ve button'ları bul ve font uygula
	if node is Label:
		apply_font_to_label(node as Label)
	elif node is Button:
		apply_font_to_button(node as Button)
	
	# Tüm child'ları kontrol et
	for child in node.get_children():
		apply_fonts_recursive(child)

