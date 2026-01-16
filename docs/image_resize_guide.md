# Godot'da PNG Görsellerini Küçültme Rehberi

## Sorun
TextureRect'te görseller crop ediliyor, küçültülmüyor. Görselleri gerçekten küçültmek gerekiyor.

## Çözüm: Texture2D Yükleyip ImageTexture'a Çevirip Resize Et

**YANLIŞ YÖNTEM (Export'ta çalışmaz):**
```gdscript
var image = Image.new()
image.load(sprite_path)  # Export'ta çalışmaz!
```

**DOĞRU YÖNTEM:**
```gdscript
# Texture2D olarak yükle (export'ta çalışır)
var texture = load(sprite_path) as Texture2D
if texture and texture is ImageTexture:
    var image_texture = texture as ImageTexture
    var image = image_texture.get_image()
    
    if image and not image.is_empty():
        # Görseli hedef boyutuna küçült (aspect ratio korunarak)
        var target_size = 50
        var original_size = image.get_size()
        var scale = min(float(target_size) / original_size.x, float(target_size) / original_size.y)
        var new_size = (original_size * scale).round()
        
        # Görseli resize et
        if new_size.x > 0 and new_size.y > 0:
            var resized_image = image.duplicate()
            resized_image.resize(int(new_size.x), int(new_size.y), Image.INTERPOLATE_LANCZOS)
            
            # Küçültülmüş görselden ImageTexture oluştur
            var resized_texture = ImageTexture.create_from_image(resized_image)
            
            # TextureRect'te kullan
            texture_rect.texture = resized_texture
```

## Önemli Noktalar

1. **load() ile Texture2D yükle**: PNG'yi Texture2D olarak yükle (export'ta çalışır)
2. **ImageTexture'a çevir**: Texture2D'yi ImageTexture'a çevir ve get_image() ile Image al
3. **Aspect ratio koru**: `min()` kullanarak her iki boyutu da kontrol et
4. **Lanczos interpolasyonu**: Kaliteli küçültme için `Image.INTERPOLATE_LANCZOS` kullan
5. **ImageTexture.create_from_image()**: Küçültülmüş Image'den yeni texture oluştur

## Kullanım Senaryosu

Karakter seçim ekranında görselleri butonlara sığdırmak için:
- Görseli 50x50 boyutuna küçült
- Padding 20px (her tarafta)
- TextureRect'te `STRETCH_KEEP_ASPECT_CENTERED` kullan

