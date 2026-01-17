extends Node
# Font Manager - Sayılar için Bake Soda, yazılar için Nunito

var number_font: FontFile = null
var text_font: FontFile = null
var text_font_bold: FontFile = null # Butonlar için bold font

# Font path'leri
const BAKE_SODA_PATH = "res://assets/font/BakeSoda.otf"
const NUNITO_REGULAR_PATH = "res://assets/font/Nunito-Regular.ttf"
const NUNITO_BOLD_PATH = "res://assets/font/Nunito-Bold.ttf"

func _ready() -> void:
	# Font'ları runtime'da yükle (import edilmemiş olsa bile hata vermez)
	number_font = _load_font_safe(BAKE_SODA_PATH)
	text_font = _load_font_safe(NUNITO_REGULAR_PATH)
	text_font_bold = _load_font_safe(NUNITO_BOLD_PATH)

# Güvenli font yükleme - import edilmemiş olsa bile hata vermez
func _load_font_safe(path: String) -> FontFile:
	# Önce ResourceLoader ile kontrol et
	if ResourceLoader.exists(path):
		var resource = load(path)
		if resource is FontFile:
			return resource as FontFile
	
	# ResourceLoader bulamazsa, direkt dosya yolunu dene (import edilmemiş olabilir)
	# Bu durumda Godot'un import etmesini bekle
	return null

# Font'un gerçekten kullanılabilir olup olmadığını kontrol eden yardımcı fonksiyon
# Burada yalnızca null ve instance geçerliliğini kontrol ediyoruz; FontFile zaten
# doğrudan preload edildiği için bu genelde yeterli.
func _is_font_valid(font: FontFile) -> bool:
	return font != null and is_instance_valid(font)

func get_number_font() -> FontFile:
	return number_font

func get_text_font() -> FontFile:
	return text_font

func is_number_only(text: String) -> bool:
	# Sadece sayılar ve boşluk içeriyor mu kontrol et
	if text.is_empty():
		return false
	
	# Sayılar, boşluk, nokta, virgül, eksi işareti ve slash (/) içerebilir
	# Ayrıca "LV." ile başlıyorsa da sayı fontu kullan (Level göstergesi için)
	if text.begins_with("LV."):
		return true

	var number_pattern = RegEx.new()
	number_pattern.compile("^[0-9\\s\\.\\-\\,\\/]+$")
	return number_pattern.search(text) != null

func apply_font_to_label(label: Label) -> void:
	if not label or not is_instance_valid(label):
		return
	
	var text = label.text
	var font_to_use: FontFile = null
	
	# Font seçimi
	if is_number_only(text):
		# Sadece sayı içeriyorsa Bake Soda kullan
		font_to_use = number_font
		if not font_to_use and text_font:
			font_to_use = text_font # Fallback
		if not font_to_use and text_font_bold:
			font_to_use = text_font_bold # Fallback
	else:
		# Yazı içeriyorsa Nunito Regular kullan
		font_to_use = text_font
		if not font_to_use and text_font_bold:
			font_to_use = text_font_bold # Fallback
		if not font_to_use and number_font:
			font_to_use = number_font # Fallback
	
	# Font'u güvenli bir şekilde uygula
	# Font yoksa veya geçersizse hiçbir şey yapma, sistem font'u kullanılacak
	if not _is_font_valid(font_to_use):
		# Font yoksa override'ı kaldır, sistem font'unu kullan
		label.remove_theme_font_override("font")
		return
	
	# Font geçerli, Nunito font'unu uygula
	label.add_theme_font_override("font", font_to_use)

func apply_font_to_button(button: Button) -> void:
	if not button or not is_instance_valid(button):
		return
	
	var text = button.text
	if text.is_empty():
		# Text yoksa font uygulamaya gerek yok
		return
	
	var font_to_use: FontFile = null
	
	# Font seçimi
	if is_number_only(text):
		# Sadece sayı içeriyorsa Bake Soda kullan
		font_to_use = number_font
		if not font_to_use and text_font:
			font_to_use = text_font # Fallback
		if not font_to_use and text_font_bold:
			font_to_use = text_font_bold # Fallback
	else:
		# Yazı içeriyorsa Nunito Bold kullan (butonlar için)
		font_to_use = text_font_bold
		if not font_to_use and text_font:
			font_to_use = text_font # Fallback to regular
		if not font_to_use and number_font:
			font_to_use = number_font # Fallback
	
	# Font'u güvenli bir şekilde uygula
	# Font yoksa veya geçersizse hiçbir şey yapma, sistem font'u kullanılacak
	if not _is_font_valid(font_to_use):
		# Font yoksa override'ı kaldır, sistem font'unu kullan
		button.remove_theme_font_override("font")
		return
	
	# Font geçerli, Nunito font'unu uygula
	button.add_theme_font_override("font", font_to_use)

func apply_fonts_recursive(node: Node) -> void:
	if not node or not is_instance_valid(node):
		return
	
	# Recursive olarak tüm label ve button'ları bul ve font uygula
	if node is Label:
		apply_font_to_label(node as Label)
	elif node is Button:
		apply_font_to_button(node as Button)
	
	# Tüm child'ları kontrol et
	for child in node.get_children():
		if child and is_instance_valid(child):
			apply_fonts_recursive(child)
